class CdnPushJob < PushJob
  include LivePushTasks
  include ShadowPush
  include CdnRhnPubOptions
  include CdnRhnLivePubOptions

  before_create do
    unless errata.pushcount?
      if advisory_is_cdn_only? && !is_nochannel?
        self.pre_push_tasks << 'set_issue_date'
        self.pre_push_tasks << 'set_update_date'
        self.pre_push_tasks.uniq!
      end
    end
    # explicitly set pub options to false if missing
    %w(push_files push_metadata).each { |k| pub_options[k] = pub_options.fetch(k, false) }
  end

  # Only skip pub tasks if neither metadata or files are being pushed.
  def skip_pub_task_and_post_process_only?
    !pub_options['push_metadata'] && !pub_options['push_files']
  end

  def valid_pre_push_tasks
    PRE_PUSH_TASKS
  end

  def valid_post_push_tasks
    valid_post_push_tasks_for_push_type(:cdn)
  end

  def valid_pub_options
    options = PUB_OPTIONS.merge(shadow_pub_options('Push to shadow repos'))
    if errata.has_docker?
      options['push_files'] = options['push_files'].deep_dup
      options['push_files'][:default] = false
      options['push_files'][:hidden] = true
    end
    options
  end

  def push_details
    res = Hash.new
    res['should'] = errata.supports_cdn?
    res['can'] = can_push?
    res['blockers'] = push_blockers
    res['target'] = self.target if errata.supports_cdn?
    res
  end

  # RHN and CDN push are tied together.
  # If an active RHN push job exists, our can_push logic needs to change a bit
  def push_type_for_validate
    if advisory_rhn_live_pushed?
      'cdn_if_live_push_succeeds'
    end
  end

  def can_push?(type = nil)
    type ||= push_type_for_validate
    super(type)
  end

  def validate_can_push?(type = nil)
    type ||= push_type_for_validate
    super(type)
  end

  def push_blockers(type = nil)
    type ||= push_type_for_validate
    super(type)
  end

  protected
  def advisory_is_cdn_only?
    errata.supports_cdn? && !errata.supports_rhn_live?
  end

  private
  def advisory_rhn_live_pushed?
    RhnLivePushJob.for_errata(errata).where('status != "FAILED"').exists?
  end

end
