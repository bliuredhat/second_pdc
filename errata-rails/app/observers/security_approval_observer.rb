class SecurityApprovalObserver < ActiveRecord::Observer
  OBSERVE_CLASSES = [
    Errata,
    ErrataBrewMapping,
    FiledBug,
    FiledJiraIssue,
    DroppedBug,
    DroppedJiraIssue,
    RHBA,
    RHEA,
    RHSA,
    PdcRHBA,
    PdcRHEA,
    PdcRHSA,
  ]

  observe *OBSERVE_CLASSES

  # ErrataBrewMapping -> errata_brew_mapping, etc.
  def find_type(record)
    klass = OBSERVE_CLASSES.find{|k| record.kind_of?(k)}
    return unless klass
    klass.name.underscore
  end

  def dispatch(record, event)
    record_type = find_type(record)
    return unless record_type

    method = "after_#{event}_#{record_type}"
    return unless self.respond_to?(method)

    self.send(method, record)
  end

  def after_update(record)
    dispatch(record, :update)
  end

  def after_create(record)
    dispatch(record, :create)
  end

  def after_rollback(*args)
    security_invalidate_reasons.clear
  end

  def after_commit(*args)
    security_invalidate_reasons.each do |errata_id,reasons|
      invalidate_security_on(Errata.find(errata_id), reasons)
    end
  ensure
    security_invalidate_reasons.clear
  end

  def invalidate_security_on(e, reasons)
    # NOTE: reasons can be a Set or String,
    # In case of Set
    # Array.wrap(Set.new[:foo]).sort.join(',') returns <Set 0xdeadbeef> which
    # isn't what we want. So; we need to call to_a before Array.wrap
    # String.respond_to?(:to_a) is false the line below 'Array.wrap would
    # handle the case when reasons is a String

    # So if reasons can be converted to_a, lets do that
    reasons = reasons.to_a if reasons.respond_to?(:to_a)
    e.invalidate_security_approval!(:reason => Array.wrap(reasons).sort.join(', '))
  end

  def invalidate_security_later_on(e, why)
    security_invalidate_reasons[e.id] << why
  end

  def invalidate_security_later_on_related(object, why)
    invalidate_security_later_on(object.errata, why)
  end

  def after_create_filed_bug(fb)
    invalidate_security_later_on_related(fb, 'changed bugs')
  end

  def after_create_dropped_bug(db)
    invalidate_security_later_on_related(db, 'changed bugs')
  end

  def after_create_filed_jira_issue(fi)
    invalidate_security_later_on_related(fi, 'changed JIRA issues')
  end

  def after_create_dropped_jira_issue(di)
    invalidate_security_later_on_related(di, 'changed JIRA issues')
  end

  def after_approve_docs!(errata)
    errata.auto_request_security_approval
  end

  def after_disapprove_docs!(errata)
    if !User.current_user.in_role?('secalert')
      invalidate_security_on(errata, 'docs not approved')
    end
  end

  def after_update_errata(errata)
    if errata.status_changed? && errata.status_in?(:NEW_FILES, :DROPPED_NO_SHIP)
      invalidate_security_on(errata, 'status change')
    end
  end

  private
  def security_invalidate_reasons
    Thread.current[:security_approval_observer_invalidate_reasons] ||= Hash.new{|h,k| h[k] = Set.new}
  end
end
