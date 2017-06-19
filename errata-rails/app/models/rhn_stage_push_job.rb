class RhnStagePushJob < PushJob
  include StagePushPriority
  include CdnRhnPubOptions

  before_create do
    # explicitly set pub options to false if missing
    %w(push_files push_metadata).each { |k| pub_options[k] = pub_options.fetch(k, false) }
  end

  def valid_post_push_tasks
    tasks = {
      'mark_rhnqa_done' => {
        :mandatory   => true,
        :description => "Mark distqa push as done.",
      },

      'reschedule_rhnqa' => {
        :mandatory   => true,
        :description => "Reschedule TPS RHNQA jobs after submitting the errata.",
      }
    }
    tasks
  end

   def enqueue!
    raise "Cannot enqueue this job" unless can_enqueue?
    self.status = 'QUEUED'
    # Replace with beginning_of_hour in rails 3.2
    # Schedule for top of next closest hour
    next_hour = 1.hour.from_now.change(:min => 0)
    send_at(next_hour, :submit_queued_job)
    info "Enqueued push job. Submitting to pub at #{next_hour.to_s}"
    self.save!
  end

  def submit_queued_job
    if errata.can_push_to? push_type
      self.create_pub_task(Push::PubClient.get_connection)
    else
      warn "Errata #{errata.id} can no longer push to RHN Stage: #{errata.push_rhn_stage_blockers.join("\n")}"
    end
  end
  
  def push_details
    res = Hash.new
    res['should'] = true
    res['can'] = errata.can_push_to? push_type
    res['blockers'] = errata.push_blockers_for(push_type)
    res['target'] = self.target
    res
  end

  def can_enqueue?
    self.errata && self.errata.release_versions.any? { |rv| rv.is_at_least_rhel5? }
  end

  protected

  # stage specific task
  def task_reschedule_rhnqa
    reschedule_tps_jobs(:rhnqa)
  end

  def task_mark_rhnqa_done
    errata.update_attribute(:rhnqa, true)
  end

end
