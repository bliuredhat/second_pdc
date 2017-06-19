class JobTrackersController < ApplicationController
  respond_to :html
  respond_to :json, :only => :show

  around_filter :with_validation_error_rendering

  def index
    @job_trackers = JobTracker.order('id desc').paginate(:page => params[:page] || 1, :per_page => 200)
    set_page_title "Background Job Trackers"
    respond_with(@job_trackers)
  end

  def show
    extra_javascript 'view_section'
    @job_tracker = JobTracker.find params[:id]
    set_page_title [@job_tracker.name, @job_tracker.description, @job_tracker.state].join(' - ')
    respond_with(@job_tracker)
  end
end
