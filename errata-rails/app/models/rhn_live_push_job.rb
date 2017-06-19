require 'rexml/document'

class RhnLivePushJob < PushJob
  include LivePushTasks
  include ShadowPush
  include CdnRhnPubOptions
  include CdnRhnLivePubOptions

  validate :rhsa_only_tasks

  def can_push?
    return false unless super
    check_oval_well_formed
  end

  def validate_can_push?
    super
    unless check_oval_well_formed
      errors.add_to_base("OVAL is not well formed!")
    end
  end

  before_create do
    unless errata.pushcount? || is_nochannel?
      self.pre_push_tasks << 'set_issue_date'
      self.pre_push_tasks << 'set_update_date'
      self.pre_push_tasks.uniq!
    end
    # explicitly set pub options to false if missing
    %w(push_files push_metadata).each { |k| pub_options[k] = pub_options.fetch(k, false) }
  end

  # Only skip pub tasks if neither metadata or files are being pushed.
  # Go straight to post push tasks. See bug 921580
  def skip_pub_task_and_post_process_only?
    !pub_options['push_metadata'] && !pub_options['push_files']
  end

  def valid_pre_push_tasks
    PRE_PUSH_TASKS
  end

  def valid_pub_options
    PUB_OPTIONS.merge(shadow_pub_options('Push to shadow channels')).tap do |o|
      # For this option, make this text a bit more helpful to guide the user
      # in the push UI
      o['push_metadata'][:description] = \
        'Submit errata to Red Hat Network; (Uncheck only if this errata is ' +
        'already pushed correctly but you want to do things like close the ' +
        'Bugzilla bugs or update the push count)'
    end
  end

  def valid_post_push_tasks
    valid_post_push_tasks_for_push_type(:rhn_live)
  end

  def push_details
    res = Hash.new
    res['should'] = true
    res['can'] = can_push?
    res['blockers'] = push_blockers
    res['target'] = self.target
    res
  end

  protected

  def check_oval_well_formed
    return true unless errata.supports_oval?
    begin
      info "Checking that oval is well formed..."
      r = TextRender::OvalRenderer.new(errata)
      oval = r.get_text
      REXML::Document.new(oval)
      info "done."
      return true
    rescue => e
      msg = e.message
      msg.gsub!('#<RuntimeError: ','')
      error "OVAL is not well formed:"
      error msg[0..500]
      return false
    end
  end

  def rhsa_only_tasks
    return if errata.is_security?
    pre_push_tasks.each do |task_name|
      task = PRE_PUSH_TASKS[task_name]
      if task && task[:rhsa_only]
        errors.add(:tasks, "Task #{task_name} is valid only for RHSA.")
      end
    end
    post_push_tasks.each do |task_name|
      task = POST_PUSH_TASKS[task_name]
      if task && task[:rhsa_only]
        errors.add(:tasks, "Task #{task_name} is valid only for RHSA.")
      end
    end
  end
end
