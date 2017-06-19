class ErrataAuditObserver < ActiveRecord::Observer
  #
  # We register the observer for the klass descendents of Errata. It
  # seems there are differences during the registration process when
  # Single Table Inheritence (STI) is involved. We found that this
  # observer is registered for an :errata on application/test startup,
  # but later on the registration vanishes:
  #
  #   @errata.class.observer_instances
  #   => []
  #
  # The configuration `config.cache_classes = false` makes it to work
  # again, but comes with a performance impact. There is no clear
  # understanding as to why the registration vanishes, but it's
  # possibly related to calls to klass.descendants giving different
  # results depending on whether the subclasses have been loaded yet.
  #
  # Probably don't need to include the base class as well, but add it
  # just in case there is a weird edge case where an instaniated object
  # has a class of Errata.
  #
  # Bug: 1067901
  #
  observe Errata, RHSA, RHBA, RHEA

  def after_update(errata)
    audit_release_date(errata) if errata.release_date_changed?

    if errata.supports_multiple_product_destinations_changed?
      after_supports_multiple_product_destinations_changed(errata)
    end

    check_object_change errata, 'product'
    check_object_change errata, 'batch'
    check_object_change errata, 'release', :errata_attribute => 'group_id'
    check_object_change errata, 'assigned_to', :object_class => User, :object_attribute => :login_name

    check_attr_change errata, 'security_approved'
    check_attr_change errata, 'state_rule_set', :errata_attribute => 'state_machine_rule_set_id'
    check_attr_change errata, 'batch_blocker', :errata_attribute => 'is_batch_blocker'
  end

  # Check if an attribute has changed on an +errata+ and audit if so.
  #
  # +external_attribute+ is the name of the attribute used in ErrataActivity
  # records and message bus messages.
  #
  # +args+ is a hash of additional arguments, all optional:
  #
  #   :errata_attribute - the internal name of the attribute on the errata
  #                       object; defaults to same as +external_attribute+
  #
  #   :serialize - a proc which will be given the attribute's value and should
  #                return a simple value (string or integer) to be stored on
  #                ErrataActivity records and message bus messages
  #
  def check_attr_change(errata, external_attribute, args = {})
    errata_attribute = args[:errata_attribute] || external_attribute
    return unless errata.send("#{errata_attribute}_changed?")

    serialize = args[:serialize] || lambda{ |x| x }

    old_attr = errata.changed_attributes[errata_attribute]
    old_val  = serialize[old_attr]
    new_attr = errata.send(errata_attribute)
    new_val  = serialize[new_attr]

    audit_change errata, external_attribute, old_val, new_val
  end

  # Like +check_attr_change+ but with defaults appropriate for auditing the
  # change of an object related to an +errata+.
  #
  # +args+ accepts these arguments (as well as those accepted by +check_attr_change+):
  #
  #   :object_class - class of the related object; by default, derived from +external_attribute+
  #
  #   :object_attribute - the attribute of the object to be stored/sent; default is :name
  #
  def check_object_change(errata, external_attribute, args = {})
    object_class     = args[:object_class] || external_attribute.capitalize.constantize
    object_attribute = args[:object_attribute] || :name

    args[:errata_attribute] ||= "#{external_attribute}_id"
    args[:serialize]        ||= lambda{ |id| object_class.find_by_id(id).try(object_attribute) }

    check_attr_change errata, external_attribute, args
  end

  def after_approve_docs!(errata)
    ErrataActivity.create!(:errata => errata, :what => 'docs_approved')
    errata.comments << DocsApprovalComment.new(:text => "Errata documentation has been APPROVED.")
  end

  def after_disapprove_docs!(errata)
    ErrataActivity.create!(:errata => errata, :what => 'docs_rejected')
    errata.comments << DocsApprovalComment.new(:text => "Errata documentation has been DISAPPROVED.")
  end

  def after_request_docs_approval!(errata)
    ErrataActivity.create!(:errata => errata, :what => 'docs_approval_requested')
    errata.comments << DocsApprovalComment.new(:text => "Documentation approval requested.")

    Notifier.request_docs_approval(errata).deliver
  end

  def after_supports_multiple_product_destinations_changed(errata)
    return unless errata.supports_multiple_product_destinations?

    # Don't notify now if filelist is unlocked, since files might still change.
    # (We'll notify later on a state transition.)
    return if errata.filelist_unlocked?

    Notifier.multi_product_activated(errata).try(:deliver)
  end

  def audit_release_date(errata)
    old_r = errata.release_date_was.strftime('%Y-%b-%d') unless errata.release_date_was.nil?
    new_r = errata.release_date.strftime('%Y-%b-%d') unless errata.release_date.nil?
    old_r ||= 'UNSET'
    new_r ||= 'UNSET'

    ErrataActivity.create!(:errata => errata, :what => 'embargo_date', :removed => old_r, :added => new_r )
    errata.comments.create!(:text => "Embargo date changed from #{old_r} to #{new_r}")
  end

  def security_approved_changed_comment(errata, from, to)
    transition = SecurityWorkflow::SECURITY_APPROVED_TRANSITIONS[[from,to]]
    comment = transition[:comment]
    if to.nil? && (reason = errata.security_invalidate_reason).present?
      comment = "#{comment} due to #{reason}"
    end

    if transition[:what] == :rescinded
      comment = "#{comment}.\n\n#{SecurityWorkflow::RESCIND_NOTE}"
    end
    SecurityApprovalComment.new(text: "#{comment}.")
  end

  def batch_changed_comment(errata, from, to)
    comment = if from.nil?
      "Advisory batch has been set to '#{to}'."
    elsif to.nil?
      "Advisory has been removed from batch '#{from}'."
    else
      "Advisory batch changed from '#{from}' to '#{to}'."
    end
    BatchChangeComment.new(text: comment)
  end

  def batch_blocker_changed_comment(errata, from, to)
    comment = to ?
      "Advisory is set to be a batch blocker" :
      "Advisory is no longer a batch blocker"
    BatchChangeComment.new(text: comment)
  end

  def assigned_to_changed_comment(errata, from, to)
    # We do not generate a comment in this case because, in the typical case, a
    # controller is already doing that (and might include additional info in the
    # same comment).
    nil
  end

  private
  def audit_change(errata, attribute, from, to)
    return if from == to
    ErrataActivity.create!(:errata => errata, :what => attribute, :removed => from, :added => to )
    method = "#{attribute}_changed_comment"
    comment = if self.respond_to?(method)
      self.send(method, errata, from, to)
    else
      Comment.new(text: "#{attribute.humanize} changed from #{from} to #{to}")
    end
    errata.comments << comment if comment.present?
  end
end
