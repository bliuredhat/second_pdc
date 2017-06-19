class AdvisoryForm
  require 'diffstring'
  include FormObject
  include IsValidDatetime

  attr_accessor :errata, :content, :params, :who, :diffs, :bugs, :jira_issues, :enable_release_date, :enable_embargo_date

  validate \
    :advisory_valid,
    :date_fields_valid,
    :issues_valid,
    :manager_package_owner_valid,
    :assigned_to_email_valid,
    :create_async_valid,
    :security_valid,
    :quality_responsibility_name_valid

  delegate \
      :advisory_name,
      :allow_edit?,
      :can_have_text_only_cpe?,
      :closed?,
      :cve_list,
      :doc_complete,
      :docs_approval_requested?,
      :docs_approved?,
      :docs_status_text,
      :errata_type,
      :fulladvisory,
      :fulltype,
      :id,
      :is_security?,
      :is_pdc?,
      :issue_date,
      :product,
      :reboot_suggested,
      :release,
      :security_approved,
      :security_impact,
      :status,
      :status_is?,
      :synopsis,
      :synopsis_sans_impact,
      :text_only,
      :text_ready,
      :update_date,
      :supports_multiple_product_destinations,
    :to => :errata

  delegate :text_only_cpe,
           :reference,
           :topic,
           :solution,
           :cve,
           :description,
           :crossref,
           :keywords,
           :product_version_text,
           :to => :content

  def self.content_keys
    [:cve, :topic, :keywords, :description, :text_only_cpe, :reference, :crossref, :solution, :product_version_text]
  end

  # Keys which may be directly written from params into errata
  def self.errata_write_keys
    [
      :closed,
      :publish_date_override,
      :release_date,
      :security_approved,
      :security_impact,
      :supports_multiple_product_destinations,
      :synopsis,
      :text_only,
    ]
  end

  # Keys which may be read from errata and included in result
  def self.errata_read_keys
    self.errata_write_keys + [
      :doc_complete,
      :reboot_suggested,
    ]
  end

  # Keys which are omitted from clone
  def self.errata_uncloneable_keys
    [
      # docs must be newly approved/approval requested on newly cloned
      # advisory
      :doc_complete,
      :text_ready,

      # same for product security approval
      :security_approved,

      # newly cloned advisory shouldn't start as closed
      :closed,

      # do not copy QE assignee (bz1251531)
      :assigned_to_email,

      # builds not copied so 'Support Multiple Products' also wouldn't
      # need to be copied
      :supports_multiple_product_destinations,
    ]
  end

  def self.errata_to_params(advisory)
    params = {:id => advisory.id,
      :product => {:id => advisory.product.id},
      :release => {:id => advisory.release.id},
      :advisory => {:idsfixed => advisory.issue_list.join(' '),
        :errata_type => advisory.errata_type}
    }
    errata_read_keys.each {|k| params[:advisory][k] = advisory.send(k)}
    content_keys.each {|k| params[:advisory][k] = advisory.content.send(k)}
    params[:advisory][:release_date] = format_date advisory.release_date
    params[:advisory][:publish_date_override] = format_date advisory.publish_date_override
    params[:advisory][:enable_embargo_date] = 'on' if advisory.release_date.present?
    params[:advisory][:enable_release_date] = 'on' if advisory.publish_date_override.present?
    params[:advisory][:assigned_to_email] = advisory.assigned_to.login_name
    params[:advisory][:manager_email] = advisory.manager.login_name
    params[:advisory][:package_owner_email] = advisory.package_owner.login_name
    params[:advisory][:synopsis] = advisory.synopsis_sans_impact
    params
  end

  def self.clone_errata_by_params(who, params)
    #
    # This is shared code, so we keep the guesswork on which advisory to
    # clone from in here. (see errata controller and api/v1/erratum
    # controller.
    #
    clone_id = params[:errata] && params[:errata][:clone]
    clone_id ||= params[:id]
    old = Errata.find_by_advisory(clone_id)
    result = AdvisoryForm.errata_to_params(old)
    result.deep_merge! params.deep_symbolize_keys
    result[:advisory].except! *AdvisoryForm.errata_uncloneable_keys
    ap = result[:advisory]

    if old.is_security? && !who.in_role?('secalert')
      # User cloned from an RHSA but is not a secalert user. Convert to an RHBA
      # and clear reference. (Reference contains a link to the security classification.
      # In theory it could contain other preservable links but let's not worry
      # about it).
      ap[:errata_type] = 'RHBA'
      ap[:reference] = ''
    end
    result
  end

  def initialize(who, form_params = {})
    self.who = who
    self.params = form_params
    set_advisory
    self.content = self.errata.content
    self.diffs = {}
    update_attributes unless self.params[:advisory].blank?
  end

  def new_record?
    true
  end

  def persisted?
    @persisted
  end

  def can_change_release?
    true
  end

  def cve_problems
    problems = errata.cve_problems
    return problems unless errata.is_security?

    bugdesc = bugs.buglist.reject{ |b| b.is_security_tracking? }.collect { |b| b.short_desc }.join(' ')
    bug_cves = bugdesc.scan(/C[AV][NE]-\d+-\d+/).collect {|cve| cve.split('-',2)[1]}.to_set
    errata_cves = errata.cve_list.collect {|cve| cve.split('-',2)[1]}.to_set

    # CVE aliases start with "CVE-" or (rarely) "CAN-"
    cve_aliases = bugs.buglist.select(&:is_security_vulnerability?).
      map(&:aliases).flatten.grep(/^C(VE|AN)-\d+-\d+/).collect {|cve| cve.split('-',2)[1]}.to_set

    notinlist = (bug_cves - errata_cves).collect {|cve| "CVE-#{cve}"}
    problems[:idsfixed] << "Your bug list references the following CVE names that are not included in the CVE list: #{notinlist.join(', ')}" unless notinlist.empty?

    notinsummary = (errata_cves - bug_cves).collect {|cve| "CVE-#{cve}"}
    problems[:cve] << "The following CVE names appear in the CVE names list but not in the summary of any linked bugzilla bug: #{notinsummary.join(', ')}" unless notinsummary.empty?

    not_in_aliases = (errata_cves - cve_aliases).collect {|cve| "CVE-#{cve}"}
    problems[:cve] << "The following CVE names appear in the CVE names list but not in the aliases of any linked bugzilla bug: #{not_in_aliases.join(', ')}" unless not_in_aliases.empty?

    aliases_not_in_list = (cve_aliases - errata_cves).collect {|cve| "CVE-#{cve}"}
    problems[:idsfixed] << "Your bug list includes the following CVE aliases that are not included in the CVE list: #{aliases_not_in_list.join(', ')}" unless aliases_not_in_list.empty?

    problems
  end

  def diff_edits(diff_from_empty = false)
    {}
  end

  def diffs_to_text(changes = nil)
    changes ||= self.diffs
    text_changes = ''
    changes.each_pair do |field, diff|
      text_changes += "#{field.to_s} changed:\n"
      text_changes += diff
      text_changes += "\n"
    end
    text_changes.strip
  end

  def docs_have_changed?
    self.diffs.any? || self.issues_have_changed?
  end

  def changed_issues
    @changed_issues ||= [bugs, jira_issues].each_with_object(HashList.new) do |issues, h|
      (add, drop) = issues.issues_to_add_and_drop
      h[:add].concat(add)
      # The current implementation doesn't rescind docs approval when issues are dropped.
      # Not sure whether it is a feature or not. Therefore, I commented the following line.
      # Simply un-comment it should the condition had changed.
      # h[:drop].concat(drop)
    end
  end

  def changed_issues_diff_text
    text_changes = ''
    changes = self.changed_issues
    text_changes = "Bugs/JIRA Issues changed:\n\n"
    [ ['+', :add], ['-', :drop] ].each do |sign,key|
      next unless changes[key].any?
      (bugs, jira_issues) = changes[key].partition{|i| i.kind_of?(Bug)}
      text_changes += "#{sign} " + (bugs.map(&:id).sort + jira_issues.map(&:key).sort).join(" ") + "\n"
    end
    text_changes.strip
  end

  def issues_have_changed?
    changed_issues.values.flatten.any?
  end

  def release_date
    self.class.format_date errata.release_date
  end

  def publish_date_override
    self.class.format_date errata.publish_date_override
  end

  def idsfixed
    out = unless params.nil? || params[:advisory].nil?
      params[:advisory][:idsfixed]
    end
    out ||= "#{bugs.resolved_idsfixed.join(' ')} #{jira_issues.resolved_idsfixed.join(' ')}".strip
    out
  end

  # Compensate for some synopsis massaging that happens in
  # the errata model in the before_save callback
  def synopsis_preview(e = nil)
    e ||= errata
    if e.is_security?
      "#{e.security_impact}: #{e.synopsis_sans_impact}"
    else
      e.synopsis
    end
  end

  def synopsis_preview_from_params
    adv = params[:advisory]
    return unless adv
    if adv[:errata_type] == 'RHSA' || adv[:errata_type] == 'PdcRHSA'
      "#{adv[:security_impact]}: #{adv[:synopsis]}"
    else
      adv[:synopsis]
    end
  end

  def persist!
    set_manager_and_package_owner
    set_assigned_to
    set_quality_responsibility
    handle_docs_approval! do
      Errata.transaction do
        errata.save!
        content.save!
        bugs.save!
        jira_issues.save!
      end
    end
    @persisted = true
  end

  def assigned_to_email
    result = params[:advisory] && params[:advisory][:assigned_to_email]
    result ||= (errata.assigned_to || User.default_qa_user).try(:login_name)
    result
  end

  def manager_email
    result = params[:advisory] && params[:advisory][:manager_email]
    result ||= errata.manager.try(:login_name)
    result
  end

  def package_owner_email
    result = params[:advisory] && params[:advisory][:package_owner_email]
    result ||= errata.package_owner.try(:login_name)
    result
  end

  def set_manager_and_package_owner
    errata.package_owner = User.find_by_login_name package_owner_email
    errata.manager = User.find_by_login_name manager_email
  end

  def set_assigned_to
    current_qe_user = errata.assigned_to
    errata.assigned_to = User.find_by_login_name assigned_to_email
    if !current_qe_user.nil? && current_qe_user != errata.assigned_to
      errata.comments.create(:who => @user, :text => "Changed QE owner from #{current_qe_user} to #{errata.assigned_to}")
    end
  end

  def set_quality_responsibility
    current_qe_group = errata.quality_responsibility
    if params[:advisory] && qe_group_name = params[:advisory][:quality_responsibility_name]
      errata.quality_responsibility = QualityResponsibility.find_by_name(qe_group_name)
      if !errata.new_record? && !current_qe_group.nil? && current_qe_group != errata.quality_responsibility
        errata.comments.create(:who => @user, :text => "Changed QE group from #{current_qe_group.name} to #{errata.quality_responsibility.name}")
      end
    end
  end

  def set_dates_enabled_from_params
    @enable_embargo_date = params[:advisory][:enable_embargo_date]
    @enable_release_date = params[:advisory][:enable_release_date]
  end

  def date_enabled?(param_value)
    param_value == "on"
  end

  def clear_dates_if_not_enabled
    # See errata_text_field_with_choice helper and _edit_form.rhtml
    # (NB: the confusing field names are correct)
    errata.release_date          = nil unless date_enabled?(@enable_embargo_date)
    errata.publish_date_override = nil unless date_enabled?(@enable_release_date)
  end

  def update_attributes
    errata.attributes = params[:advisory].slice(*AdvisoryForm.errata_write_keys)
    # Rails will not update the errata_type field using
    # update_attributes. It's because this field is the
    # single table inheritance column for the Errata model
    # and is treated as protected. So to actually change
    # that we need to do it explicitly.
    errata.errata_type = params[:advisory][:errata_type] unless params[:advisory][:errata_type].nil?
    errata.content.attributes = params[:advisory].slice(*AdvisoryForm.content_keys)
    errata.product = Product.find(params[:product][:id]) if params[:product]
    errata.release = Release.find(params[:release][:id]) if params[:release]
    set_dates_enabled_from_params
    clear_dates_if_not_enabled
    idsfixed = params[:advisory][:idsfixed]
    self.bugs = BugList.new(idsfixed, errata)
    self.jira_issues = JiraIssueList.new(idsfixed, errata)
    [self.bugs, self.jira_issues].each(&:fetch)
    self.diffs = diff_edits
  end

  def errors
    @advisory_form_errors ||= ErrataErrorsWithAlias.new(super)
  end

  private

  #
  # TODO: Can we please use l10n for this?
  # I18n.l(date, :format => :short)
  # see Bug 1023230
  #
  def self.format_date(date)
    date.try(:strftime, '%Y-%b-%d')
  end

  def manager_package_owner_valid
    [:package_owner_email, :manager_email].each do |param|
      validate_login_name(param)
    end
  end

  def validate_login_name(param)
    value = self.send(param)
    if value.blank?
      errors.add(param, "cannot be blank")
    else
      errors.add(param, "#{value} is not a valid errata user") unless User.exists?(:login_name => value)
    end
    value
  end

  def assigned_to_email_valid
    value = validate_login_name(:assigned_to_email)
    user = User.find_by_login_name(value)
    return unless user
    errors.add(:assigned_to_email, "#{value} is not a QA user") unless user.in_role?('qa')
  end

  def advisory_valid
    return if errata.valid?
    errata.errors.each {|attr, msg| errors.add(attr, msg)}
  end

  def issues_valid
    # Advisories may now be created without bugs (bz1250640)
    return if bugs.buglist.empty? && jira_issues.list.empty?

    [bugs, jira_issues].each do |issue|
      unless issue.valid?
        issue.errors.each { |attr, msg| errors.add(attr, msg) }
      end
    end

    ambiguous_idsfixed = (bugs.resolved_idsfixed.to_set & jira_issues.resolved_idsfixed).to_a
    unless ambiguous_idsfixed.empty?
      errors.add(:idsfixed, "Ambiguous identifier(s): #{ambiguous_idsfixed.join(', ')}. Prefix with bz: or jira: to disambiguate")
    end

    unresolved_idsfixed = (bugs.unresolved_idsfixed.to_set & jira_issues.unresolved_idsfixed).to_a
    unless unresolved_idsfixed.empty?
      errors.add(:idsfixed, "Not a valid bug number or JIRA issue key: #{unresolved_idsfixed.join(', ')}")
    end
  end

  def date_fields_valid
    if date_enabled?(@enable_embargo_date) && !is_valid_datetime(str=params[:advisory][:release_date])
      errors.add("Embargo date", "'#{str}' is not a valid date. (Please use YYYY-MM-DD format).")
    end
    if date_enabled?(@enable_release_date) && !is_valid_datetime(str=params[:advisory][:publish_date_override])
      errors.add("Release date", "'#{str}' is not a valid date. (Please use YYYY-MM-DD format).")
    end
  end

  # Validates that limitations for security advisories are met; for non-secalert
  # users, there are some restrictions.
  def security_valid
    return if !errata.is_security? || who.in_role?('secalert')

    unprivileged_security_field_problems.each{|key,strs| strs.each{|str| errors.add(key, str)}}
  end

  def create_async_valid
    if errata.new_record? && errata.release && errata.release.name == 'ASYNC' && !who.can_create_async?
      errors.add(:who, "User does not have permission to create ASYNC advisory")
    end
  end

  def quality_responsibility_name_valid
    if params[:advisory] && qe_group_name = params[:advisory][:quality_responsibility_name]
      if QualityResponsibility.find_by_name(qe_group_name).nil?
        errors.add(:quality_responsibility_name, "'#{qe_group_name}' is not a valid qe group name.")
      end
    end
  end

  def handle_docs_approval!
    # Changing text_ready can change the value of doc_complete, and
    # vice-versa, so it's not obvious what we should do if both values
    # were provided in one request.
    #
    # To keep things simple, we simply reject such requests.
    #
    ((text_ready,text_ready_changed),(doc_complete,doc_complete_changed)) = [:text_ready, :doc_complete].map do |key|
      value = params[:advisory] && params[:advisory][key]
      changed = false
      if !value.nil?
        # normalize to 0 or 1
        value = value.to_i
        if value != 0
          value = 1
        end
        changed = value != errata.send(key)
      end
      [value, changed]
    end

    # Bug: 1215843
    # Changes checking code need to be run before saving the errata to get an accurate
    # results because :text_ready and :doc_complete could be changed anywhere within the
    # persist!. For example, bugs.save! will change the value of the :doc_complete to 0
    # if there is any bug changes.
    #
    # Note: Update Errata API allows user to approve docs (by setting :doc_complete = 1) and
    # update several errata information in a single request. Some information updates, such
    # as Bugs/Jira Issues will rescind the docs approval. A conflict will occur if user update
    # these information in a single request.
    #
    # Not sure the reason of allowing user to set :doc_complete and :text_ready directly
    # through the API. Could be a feature, maybe?
    #
    # Solution
    # Re-approve the docs if :doc_complete is set. The comment history will still show 2 steps,
    # Approval rescinded... and Docs approved...
    yield

    if text_ready_changed && doc_complete_changed
      errors.add(:doc_complete, "can't approve/disapprove docs and request docs approval in a single request")
      return
    end

    if text_ready_changed && text_ready == 1
      errata.request_docs_approval!
    end

    if doc_complete_changed
      if !who.can_approve_docs?
        errors.add(:doc_complete, "User does not have permission to approve/disapprove docs")
        return
      end

      if doc_complete == 1
        errata.approve_docs!
      else
        errata.disapprove_docs!
      end
    end
  end

  protected

  def unprivileged_security_field_problems
    out = HashList.new

    if !errata.embargo_date.nil?
      out["Embargo date"] << "cannot be set on RHSA by non-secalert users."
    end

    # blank case is validated elsewhere
    if (imp=errata.security_impact) != 'Low' && !imp.blank?
      out["Security impact"] << "cannot be set to #{imp} by non-secalert users."
    end

    # catchall in case is_low_security? is false for unknown reasons
    if out.empty? && !errata.is_low_security?
      out[:base] << "You don't have the permission to create this RHSA."
    end

    out
  end
end
