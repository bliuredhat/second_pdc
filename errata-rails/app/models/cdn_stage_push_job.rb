class CdnStagePushJob < PushJob
  include StagePushPriority
  include CdnRhnPubOptions

  before_create do
    # explicitly set pub options to false if missing
    %w(push_files push_metadata).each { |k| pub_options[k] = pub_options.fetch(k, false) }
  end

  def valid_post_push_tasks
    tasks = {
      'reschedule_cdnqa_jobs' => {
        :mandatory   => true,
        :description => 'Reschedule TPS CDNQA jobs after submitting the errata.',
      },
      'mark_rhnqa_done' => {
        :mandatory   => true,
        :description => "Mark distqa push as done.",
      }
    }
    tasks
  end

  def push_details
    res = Hash.new
    res['should'] = true
    res['can'] = self.can_push?
    res['blockers'] = errata.push_cdn_stage_blockers
    res['target'] = self.target
    res
  end

  def default_push_type; :cdn; end

  def valid_pub_options
    options = PUB_OPTIONS.deep_dup
    if errata.has_docker?
      options['push_files'][:default] = false
      options['push_files'][:hidden] = true
    end
    options
  end

  protected

  def task_reschedule_cdnqa_jobs
    reschedule_tps_jobs(:cdnqa)
  end

  def task_mark_rhnqa_done
    #
    # Note: Even though we're not dealing with rhnqa jobs here, we
    # think this is an acceptable hotfix change. For the long run, this
    # should be changed, see bug 1089816.
    #
    errata.update_attribute(:rhnqa, true)
  end
end
