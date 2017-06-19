# == Schema Information
#
# Table name: tpsruns
#
#  run_id    :integer       not null, primary key
#  errata_id :integer       not null
#  state_id  :integer       not null
#  started   :datetime
#  finished  :datetime
#  current   :integer       default(1), not null
#

class TpsRun < ActiveRecord::Base
  include ApplicationHelper

  self.table_name = "tpsruns"
  self.primary_key = "run_id"

  #--------------------------------------------------------------------
  # Originally there were "tps_jobs" and "rhnqa_jobs", but after introducing cdn
  # that terminology became ambiguous. Let's try to minimise the confusion.

  has_many :all_tps_jobs,
    :class_name => 'TpsJob',
    :foreign_key => "run_id",
    :order => "job_id ASC",
    :include => [:tps_state]

  def rhn_tps_jobs; all_tps_jobs.with_type(RhnTpsJob); end
  def cdn_tps_jobs; all_tps_jobs.with_type(CdnTpsJob); end
  def rhnqa_tps_jobs; all_tps_jobs.with_type(RhnQaTpsJob); end
  def cdnqa_tps_jobs; all_tps_jobs.with_type(CdnQaTpsJob); end

  # For when you want all the non-qa or all the qa jobs, (eg, as displayed in the UI)
  def dist_jobs; all_tps_jobs.with_type(RhnTpsJob, CdnTpsJob); end
  def distqa_jobs; all_tps_jobs.with_type(RhnQaTpsJob, CdnQaTpsJob); end

  # Aliases for backwards compatibility. (Deprecated since the names are confusing).
  alias_method :tps_jobs, :dist_jobs
  alias_method :rhnqa_jobs, :distqa_jobs
  alias_method :tps_and_rhnqa_jobs, :all_tps_jobs

  # Might not need these, but let's define them for completeness:
  def all_rhn_jobs; all_tps_jobs.with_type(RhnTpsJob, RhnQaTpsJob); end
  def all_cdn_jobs; all_tps_jobs.with_type(CdnTpsJob, CdnQaTpsJob); end

  #--------------------------------------------------------------------

  belongs_to :errata,
    :class_name => "Errata",
    :foreign_key => "errata_id"

  belongs_to :tps_state,
    :foreign_key => "state_id"

  validates_presence_of :errata
  before_create do
    self.state_id = TpsState.default
  end

  after_create do
    self.create_and_schedule_tps_jobs!
  end

  #
  # Used in NoAuth::ErrataController#get_tps_txt
  # See Bug 889013.
  #
  def tps_txt_queue_entries(opts={})
    (tps_and_rhnqa_jobs.map do |job|
      TpsJob.tps_txt_queue_entry(job, job.errata, job.repo_name) unless job.repo_name.nil?
    end).compact
  end

  def tps_txt_output(opts={})
    tps_txt_queue_entries(opts).map{ |entry| "#{entry}\n" }.join
  end

  def job_stats
    @stats ||= stats(tps_jobs)
  end

  #
  # This assumes that tps jobs are done and complete before there are
  # any distqa jobs, hence is_finished?(true) implies is_finished?(false)
  #
  def is_finished?(for_distqa = false)
    jobs_finished?(for_distqa ? :distqa_jobs : :tps_jobs)
  end

  def jobs_finished?(job_type = :tps_jobs)
    jobs = self.send(job_type)
    jobs.any? && jobs.not_finished.empty?
  end

  def tps_jobs_finished?
    jobs_finished?(:tps_jobs)
  end

  def distqa_jobs_finished?
    distqa_jobs_initialized? && jobs_finished?(:distqa_jobs)
  end
  alias_method :rhnqa_jobs_finished?, :distqa_jobs_finished?

  def distqa_jobs_initialized?
    tps_jobs_finished? && rhnqa_jobs.any?
  end
  alias_method :rhnqa_jobs_initialized?, :distqa_jobs_initialized?

  def rhnqa_stats
    return stats(rhnqa_jobs)
  end

  #
  # Invalid jobs in this TPS run
  #
  def invalid_tps_jobs
    tps_jobs.reject(&:valid_for_tps?)
  end

  def create_and_schedule_tps_jobs!(opts = {})
    _create_and_schedule_jobs_maybe(:schedule_tps_jobs, :tps_jobs, opts)
  end

  def create_and_schedule_distqa_jobs!(opts = {})
    _create_and_schedule_jobs_maybe(:schedule_distqa_jobs, :distqa_jobs, opts)
  end

  def create_and_schedule_rhnqa_jobs!(opts = {})
    _create_and_schedule_jobs_maybe(:schedule_rhnqa_jobs, :rhnqa_tps_jobs, opts)
  end

  def create_and_schedule_cdnqa_jobs!(opts = {})
    _create_and_schedule_jobs_maybe(:schedule_cdnqa_jobs, :cdnqa_tps_jobs, opts)
  end

  def reschedule_jobs!(force = true)
    create_and_schedule_tps_jobs!({
      :schedule_all   => true,
      :force_schedule => force,
      :comment        => "Rescheduled all TPS Jobs."
    })
  end

  def reschedule_distqa_jobs!(force = true)
    create_and_schedule_distqa_jobs!({
      :schedule_all   => true,
      :force_schedule => force,
      :comment        => "Rescheduled all DistQA TPS Jobs."
    })
  end

  def reschedule_rhnqa_jobs!(force = true)
    create_and_schedule_rhnqa_jobs!({
      :schedule_all   => true,
      :force_schedule => force,
      :comment        => "Rescheduled all RhnQA TPS Jobs."
    })
  end

  def reschedule_cdnqa_jobs!(force = true)
    create_and_schedule_cdnqa_jobs!({
      :schedule_all   => true,
      :force_schedule => force,
      :comment        => "Rescheduled all CdnQA TPS Jobs."
    })
  end

  def reschedule_failure_jobs!
    reschedule_failed_jobs(:tps_jobs)
  end

  def reschedule_failure_distqa_jobs!
    reschedule_failed_jobs(:distqa_jobs)
  end

  def reschedule_failed_jobs(type)
    _reschedule_jobs(self.send(type).with_states(TpsState::BAD),
                     "Rescheduled all BAD #{type.to_s.titleize}")
  end

  def reschedule_tps_and_distqa_jobs!
    reschedule_jobs!
    reschedule_distqa_jobs!
  end
  alias_method :reschedule_tps_and_rhnqa_jobs!, :reschedule_tps_and_distqa_jobs!

  def update_jobs_for_mappings!(mappings)
    old_jobs = self.tps_jobs.to_a
    updated_jobs = self.create_and_schedule_tps_jobs!({:reschedule_mappings => mappings})

    current_jobs = self.reload.tps_jobs.to_a

    removed_jobs = old_jobs - current_jobs
    added_jobs = current_jobs - old_jobs
    rescheduled_jobs = updated_jobs - added_jobs

    actions = [[removed_jobs, 'removed']]
    if updated_jobs.any?
      if updated_jobs.first.should_auto_schedule?
        actions.concat([[added_jobs, 'scheduled'], [rescheduled_jobs, 'rescheduled']])
      else
        actions.concat([[added_jobs, 'created'], [rescheduled_jobs, 'updated']])
      end
    end

    texts = []
    actions.each do |jobs, what|
      texts << "#{n_thing_or_things(jobs.length, 'TPS job')} #{what}" unless jobs.empty?
    end

    return if texts.empty?
    text = "#{texts.join(', ')} due to changed builds."
    errata.comments << TpsComment.new(:text => text)
  end

  def update_job(job, new_state, link, link_text, host = nil)
    # Assume that we are rescheduling this tps job
    return job.reschedule! if new_state.is_state?('NOT_STARTED')

    # Update the state
    previous_state = job.tps_state
    job.tps_state = new_state

    # Generally would not be setting these if rescheduling but let's not disallow
    # it. (This method gets called also from TpsService so in theory it might happen).
    job.link = link if link
    job.link_text = link_text if link_text
    job.host = host if host

    job.save!

    # Avoiding the repetitive notification and comment if there is no change on the state
    if previous_state == new_state
      TPSLOG.info "Avoiding duplicate comment about job #{job.id} on errata #{errata.id}"
      return
    end

    if new_state.is_completed_state?
      if is_finished?(job.rhnqa?)
        msg = ""
        if job.rhnqa?
          msg += "RHNQA "
        end
        msg += "Tps Runs are now complete."
        errata.comments << TpsCompleteComment.new(text: msg)
      end
    # TODO: looks it never reaches this line
    elsif new_state.is_state?('BAD')
      errata.comments << TpsComment.new(:text => "Tps Job #{job.job_id} Failed. See <a href=\"#{job.link}\">#{job.link}</a> for details.")
    end

    self.save!
  end

  private

  def _create_and_schedule_jobs_maybe(scheduler_method, type, opts = {})
    # Only schedule new jobs by default
    schedule_all = opts.fetch(:schedule_all, false)
    # If force_schedule option is true, then force jobs to schedule
    # (override the transition guard)
    force_schedule = opts.fetch(:force_schedule, false)
    comment = opts.fetch(:comment, nil)
    args = {}
    if mappings = opts[:reschedule_mappings]
      args[:reschedule_mappings] = mappings
    end
    # Create or update available tps jobs but not actually schedule them
    created_jobs = Tps::Scheduler.send(scheduler_method, self, args)
    jobs = schedule_all ? self.send(type) : created_jobs

    return [] if jobs.empty?

    if jobs.first.should_auto_schedule? || force_schedule
      # Check the state machine rule set to see whether ET should
      # schedule the TPS jobs automatically or not.
      _reschedule_jobs(jobs, comment)
    else
      # Otherwise, un-schedule existing jobs let the user to schedule them manually.
      jobs.reject{|j|created_jobs.include?(j)}.each(&:unschedule!)
    end
    TpsQueue.schedule_publication
    created_jobs
  end

  def _reschedule_jobs(jobs, comment = nil)
    return if jobs.empty?

    jobs.each do |job|
      job.reschedule!
    end

    self.tps_state = TpsState.find(TpsState::NOT_STARTED)
    self.save!
    errata.comments << TpsComment.new(:text => comment) if comment.present?
  end


  def stats(jobs)
    jobstats = Hash.new(0)
    for job in jobs do
      jobstats[job.tps_state.state] += 1
    end
    return jobstats
  end

end
