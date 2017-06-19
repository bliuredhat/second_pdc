module SecurityWorkflow
  extend ActiveSupport::Concern

  RESCIND_NOTE = "No action is required from package owner, QA owner, or docs reviewer\n" \
                 "unless requested by Product Security".freeze

  SECURITY_APPROVED_TRANSITIONS = {
    [nil, false] => {
      :what => :requested,
      :comment => 'Product Security approval requested',
      :status_check => :status_allows_security_approval?.to_proc,
      :user_check => :can_request_security_approval?.to_proc,
    },
    [false, true] => {
      :what => :granted,
      :comment => 'Product Security has APPROVED this advisory',
      :status_check => :status_allows_security_approval?.to_proc,
      :user_check => :can_approve_security?.to_proc,
    },
    [true, nil] => {
      :what => :rescinded,
      :comment => 'Product Security approval rescinded',
      :status_check => lambda{|*_| true},
      :user_check => :can_disapprove_security?.to_proc,
    },
  }

  included do
    validate :valid_security_approved

    attr_accessor :security_invalidate_reason
  end

  def requires_security_approval?
    return false if !self.is_security?
    state_machine_rule_set.state_transition_guards.where(:type => 'SecurityApprovalGuard').any?
  end

  def security_approval_requested?
    # Don't change this to !security_approved.
    # nil means not requested
    self.security_approved == false
  end

  def status_allows_security_approval?
    status_in?(security_approval_status)
  end

  def security_approval_status
    [:QE, :REL_PREP, :PUSH_READY]
  end

  def security_approval_text
    if security_approved?
      'Approved'
    elsif security_approval_requested? && !docs_approved?
      'Requested, requires docs approval'
    elsif security_approval_requested?
      'Requested'
    elsif status_allows_security_approval?
      if docs_approved?
        'Not requested'
      else
        'Not requested, requires docs approval'
      end
    else
      "State invalid. Must be one of: #{security_approval_status.join(', ')}"
    end
  end

  def can_request_security_approval?
    !security_approval_requested? && !security_approved? && status_allows_security_approval? && docs_approved?
  end

  def can_approve_security?
    security_approval_requested? && status_allows_security_approval? && docs_approved? && User.current_user.can_approve_security?
  end

  def can_disapprove_security?
    security_approved? && User.current_user.can_disapprove_security?
  end

  def invalidate_security_approval!(opts={})
    return unless self.security_approved?

    self.security_approved = nil
    self.security_invalidate_reason = opts[:reason]
    self.save!
  end

  def auto_request_security_approval()
    return unless self.requires_security_approval? && self.status_is?(:REL_PREP) && self.security_approved == nil

    self.security_approved = false
    self.save!
  end

  def valid_security_approved
    old = security_approved_was
    new = security_approved
    return if old == new

    if !new.nil?
      if !self.requires_security_approval?
        errors.add(:security_approved, 'is not used for this advisory')
        return
      end
    end

    t = SECURITY_APPROVED_TRANSITIONS[[old,new]]

    if t.nil?
      # nonsensical
      texts = {
        nil => 'not requested',
        false => 'requested',
        true => 'approved',
      }
      old_text = texts[old]||old.inspect
      new_text = texts[new]||new.inspect
      errors.add(:security_approved, "transition invalid: #{old_text} => #{new_text}")
      return
    end

    if !t[:status_check].call(self)
      errors.add(:security_approved, "cannot be #{t[:what]} while in #{self.status}")
      return
    end

    user = User.current_user
    if !t[:user_check].call(user)
      errors.add(:security_approved, "cannot be #{t[:what]} by #{user.login_name}")
      return
    end
  end

  def rcm_push_requested?
    !request_rcm_push_comment_id.nil?
  end

  def rcm_push_requested_at
    return unless rcm_push_requested?
    Comment.find(request_rcm_push_comment_id).created_at
  end

  def rcm_push_requested_by
    return unless rcm_push_requested?
    Comment.find(request_rcm_push_comment_id).who
  end

  def rcm_push_requested_text
    return unless rcm_push_requested?
    comment = Comment.find(request_rcm_push_comment_id)
    "RCM push requested at #{comment.created_at} by #{comment.who}"
  end

  def ovalplatforms
    # TODO Support PDC
    return [] if is_pdc?
    product_versions.order(:name).select(&:is_oval_product?)
  end

  def ovalid
    year = errata_year
    id_part = sprintf("%.4d", errata_id)
    return "#{year}#{id_part}"
  end

  def ovalversion
    return '2' + sprintf("%.2d", pushcount)
  end

  def supports_oval?
    ovalplatforms.any? && is_security_related?
  end

end
