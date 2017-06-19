class BackgroundJobController < ApplicationController
  before_filter :admin_restricted
  around_filter :with_validation_error_rendering

  def index
    job_records = Delayed::Job.
                  # Permanently failed jobs go at the end
                  order("attempts >= #{Delayed::Job.max_attempts} asc").
                  # Currently running jobs go at the start
                  order('locked_by desc').
                  # Other jobs are listed in the order they're likely to be run
                  order('run_at asc').
                  order('priority desc').
                  order('id desc')

    # Due to the usage of DelayedJobExhibit, a plain 'paginate' on the relation
    # won't work; we need to explicitly create a Collection to generate a
    # DelayedJobExhibit only for those objects on the current page.
    page = params[:page] || 1
    per_page = 100
    @jobs = WillPaginate::Collection.create(page, per_page, job_records.count) do |pager|
      pager.replace job_records.
                     paginate(:page => page, :per_page => per_page).
                     map{ |j| DelayedJobExhibit.new(j) }
    end

    @server_running = File.exists? Rails.root.join("tmp/pids/delayed_job.pid")
    set_page_title "Background Job Queue"
  end
  
  def job
    @job = Delayed::Job.find params[:id]
    set_page_title "Background Job #{@job.id}"
  end
end
