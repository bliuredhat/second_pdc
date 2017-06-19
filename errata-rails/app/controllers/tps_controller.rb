# :api-category: Legacy
class TpsController < ApplicationController
  include CurrentUser, ReplaceHtml
  require 'tps/job_queue'

  respond_to :js,
    :only => [:troubleshooter]

  skip_before_filter :readonly_restricted

  before_filter :find_tps_run,
    :only => [:errata_results,
              :rhnqa_results,
              :reschedule_all,
              :reschedule_all_failure,
              :reschedule_all_distqa,
              :reschedule_all_rhnqa_failure,
              :troubleshooter]
  before_filter :set_index_nav,
    :only => [:errata_results,
              :rhnqa_results,
              :open_jobs,
              :failing_jobs,
              :running_jobs]

  verify :method => :post,
  :only => [:check_for_missing_jobs,
            :check_for_missing_rhnqa_jobs,
            :delete_tps_job,
            :invalidate_queue,
            :schedule_job,
            :reschedule_all,
            :reschedule_all_distqa,
            :waive,
            :unwaive],
  :redirect_to => { :action => :running_jobs }

  after_filter :publish_queue,
  :only => [:reschedule_all,
            :reschedule_all_distqa]

  def delete_tps_job
    TpsJob.delete(params[:id])
    render_js js_remove("tps_job_#{params[:id]}")
  end

  def check_for_missing_jobs
    schedule_missing_helper(:create_and_schedule_tps_jobs!, :redirect_to_tps_run)
  end

  def check_for_missing_rhnqa_jobs
    schedule_missing_helper(:create_and_schedule_distqa_jobs!, :redirect_to_tps_rhnqa_run)
  end

  def index
    redirect_to :action => 'running_jobs'
  end

  def invalidate_queue
    publish_queue
    update_flash_notice_message('TPS Queue will be republished within 5 minutes', :type=>:notice, :nofade=>true)
  end

  def job_queue
    redirect_to :action => 'running_jobs'
  end

  def running_jobs
    @jobs = job_errata_map(TpsState::BUSY)
    set_page_title 'Running TPS Jobs'
  end

  def open_jobs
    @jobs = job_errata_map(TpsState::NOT_STARTED)
    if File.exists? Rails.root.join("public/tps.txt")
      @last_published = File.mtime(Rails.root.join("public/tps.txt")).to_s(:long)
    else
      @last_published = 'tps.txt missing!'
    end
    set_page_title 'Open TPS Jobs'
  end

  def failing_jobs
    @jobs = job_errata_map(TpsState::BAD)
    set_page_title 'Failing TPS Jobs'
  end

  #
  # Fetch the TPS jobs for an advisory.
  #
  # :api-url: /advisory/{id}/tps_jobs.json
  # :api-method: GET
  #
  # Example response:
  #
  # ```` JavaScript
  # [
  #   {
  #     "host": "",
  #     "version": "5Server",
  #     "started": "2012-06-29 08:01:45 UTC",
  #     "state": "NOT_STARTED",
  #     "job_id": 142736,
  #     "arch": "ppc",
  #     "run_id": 16384,
  #     "link_text": "",
  #     "link": "",
  #     "finished": "",
  #     "rhnqa": false
  #   },
  #   {
  #     "host": "",
  #     "version": "5Server",
  #     "started": "2012-06-29 08:01:45 UTC",
  #     "state": "NOT_STARTED",
  #     "job_id": 142737,
  #     "arch": "i386",
  #     "run_id": 16384,
  #     "link_text": "",
  #     "link": "",
  #     "finished": "",
  #     "rhnqa": false
  #   }
  # ]
  # ````
  def jobs_for_errata
    return unless find_errata
    if @errata.tps_run.nil?
      jobs = []
    else
      jobs = @errata.tps_run.tps_jobs.collect { |j| j.to_hash}
      jobs += @errata.tps_run.rhnqa_jobs.collect { |j| j.to_hash}
    end
    respond_to do |format|
      format.json { render :json => jobs.to_json }
      format.xml { render :xml => jobs.to_xml }
    end
  end

  def errata_results
    extra_javascript 'tps_jobs'
    set_page_title "Current TPS Jobs for #{@tpsrun.errata.shortadvisory}"
  end

  def rhnqa_results
    extra_javascript 'tps_jobs'
    set_page_title "Current DistQA TPS Jobs for #{@tpsrun.errata.shortadvisory}"
  end

  #
  # Find invalid jobs for the given tps run and delete them
  #
  def delete_invalid_tps_jobs
    tps_run = TpsRun.find(params[:id])
    delete_these = tps_run.invalid_tps_jobs
    if delete_these.length > 0
      deleted_ids = delete_these.map(&:id).join(', ') # just to show in message
      plural_s = delete_these.length > 1 ? "s" : "" # TODO: use helper?
      delete_these.each{ |job| job.delete }
      flash_message :notice, "Deleted invalid TPS job#{plural_s} with id#{plural_s} #{deleted_ids}."
    else
      flash_message :alert, "No invalid TPS jobs found."
    end
    redirect_to_tps_run(tps_run)
  end

  def schedule_job
    extra_javascript 'tps_jobs'
    @job = TpsJob.find(params[:id])
    @schedule_action = nil

    # If channel or cdn repo has been deleted, then destroy the job
    # If the job has not been scheduled yet, then schedule it.
    # Otherwise reschedule the job.
    if @job.dist_source.blank?
      @job.destroy
      @notice = "Job #{@job.job_id} removed (#{@job.dist_repo_name.humanize} no longer exists)"
    elsif @job.state_id == TpsState::NOT_SCHEDULED
      @schedule_action = "Scheduling"
      @notice = "Job #{@job.job_id} scheduled."
    else
      @schedule_action = "Rescheduling"
      @notice = "Job #{@job.job_id} rescheduled."
    end

    unless @schedule_action.nil?
      update_job(@job, TpsState::NOT_STARTED, @schedule_action)
    end

    respond_to do |format|
      format.js {}
    end
  end

  def reschedule_all
    reschedule_jobs_helper(:reschedule_jobs!,
                           :redirect_to_tps_run,
                           "All TPS Jobs have been rescheduled.")
  end

  def reschedule_all_failure
    reschedule_jobs_helper(:reschedule_failure_jobs!,
                           :redirect_to_tps_run,
                           "All BAD TPS jobs have been rescheduled.")
  end

  def reschedule_all_distqa
    reschedule_jobs_helper(:reschedule_distqa_jobs!,
                           :redirect_to_tps_rhnqa_run,
                           "All DistQA TPS Jobs have been rescheduled."
                          )
  end

  def reschedule_all_rhnqa_failure
    reschedule_jobs_helper(:reschedule_failure_distqa_jobs!,
                           :redirect_to_tps_rhnqa_run,
                           "All BAD DistQA TPS jobs have been rescheduled."
                          )
  end

  def waive
    job = TpsJob.find(params[:id])
    if current_user_permitted?(:waive_tps_job)
      flash_message :notice, "Job #{job.job_id} has been waived."
      update_job(job, TpsState::WAIVED, 'Waiving')
    else
      flash_message :error, "User not permitted to waive TPS jobs."
    end
    redirect_to_job_run(job)
  end

  def unwaive
    job = TpsJob.find(params[:id])
    flash_message :notice, "Job #{job.job_id} has been unwaived."
    update_job(job, TpsState::BAD, 'Unwaiving')
    redirect_to_job_run(job)
  end

  def troubleshooter
    @report_to = Settings.errata_admin_email || "errata-admin@redhat.com"
    @dist_repos = {}

    [Push::Rhn, Push::Cdn].each do |klass|
      results = klass.troubleshoot_tps(@errata)
      if results.respond_to?(:list_repos) && results.list_repos.present?
        @dist_repos[results.repo_type] = results.list_repos
      elsif results.try(:message)
        @dist_repos[results.repo_type] = "(#{results.message})"
      end
    end

    respond_to do |format|
      format.js { render :troubleshooter }
    end
  end

  private

  def find_tps_run
    if params[:id] =~ /:/
      return false unless find_errata
      @tpsrun = @errata.tps_run
    else
      @tpsrun = TpsRun.find(params[:id])
      @errata = @tpsrun.errata
    end
  end

  def publish_queue
    TpsQueue.schedule_publication
  end

  def update_job(job, newstate, action)
    job.run.update_job(job, TpsState.find(newstate), nil, nil)
    job.save

    comment = "#{action} "
    comment += "RHNQA " if job.rhnqa?
    comment += "TPS Job #{job.id}"

    job.run.errata.comments << TpsComment.new(:who => current_user, :text => comment)
  end

  def redirect_to_job_run(job)
    job.rhnqa? ? redirect_to_tps_rhnqa_run(job.run) : redirect_to_tps_run(job.run)
  end

  def redirect_to_tps_run(run)
    redirect_to :action => :errata_results, :id => run.id
  end

  def redirect_to_tps_rhnqa_run(run)
    redirect_to :action => :rhnqa_results, :id => run.id
  end

  def job_errata_map(state)
    Tps.get_jobs_in_state(state, query_advisories_for_job_map)
  end

  def query_advisories_for_job_map
    advisories = Tps.advisories_for_job_queue
    # Filter by product or release (quick hack for Bug 676619)
    @release_filter = Release.find_by_id(params[:release_id].to_i)
    @product_filter = Product.find_by_id(params[:product_id].to_i)
    @qe_team_filter = QualityResponsibility.find_by_id(params[:quality_responsibility_id].to_i)
    advisories = advisories.where(:group_id                  => @release_filter) if @release_filter
    advisories = advisories.where(:product_id                => @product_filter) if @product_filter
    advisories = advisories.where(:quality_responsibility_id => @qe_team_filter) if @qe_team_filter
    advisories
  end

  def get_secondary_nav
    return get_individual_errata_nav if ['errata_results', 'rhnqa_results'].include? params[:action]
    return [
            {:name => 'Running Jobs',
              :controller => :tps,
              :action => :running_jobs},
            {:name => 'Open Jobs',
              :controller => :tps,
              :action => :open_jobs},
            {:name => 'Failing Jobs',
              :controller => :tps,
              :action => :failing_jobs},
            {:name => 'TPS Streams',
              :controller => :tps_streams,
              :action => :index}
           ]
  end

  def schedule_missing_helper(tps_scheduler_method, redirect_method)
    run = TpsRun.find params[:id]
    created = run.send(tps_scheduler_method)
    flash_message :notice, "Created #{created.length} new jobs"
    self.send(redirect_method, run)
  end

  def reschedule_jobs_helper(tps_scheduler_method, redirect_method, flash_notice)
    @tpsrun.send(tps_scheduler_method)
    flash_message :notice, flash_notice
    self.send(redirect_method, @tpsrun)
  end

end
