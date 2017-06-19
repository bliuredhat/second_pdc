# :api-category: Background Jobs
class Api::V1::JobTrackersController < ApplicationController
  respond_to :json

  before_filter :find_job_tracker

  #
  # Retrieve a job tracker.
  #
  # A job tracker tracks the status of a group of background jobs in
  # Errata Tool.
  #
  # :api-url: /api/v1/job_trackers/{id}
  # :api-method: GET
  # :api-response-example: file:test/data/api/v1/job_trackers/show_2.json
  #
  # Valid states include:
  #
  # * `RUNNING`: jobs are currently running or are scheduled to run
  # * `FINISHED`: all jobs have completed
  # * `STALLED`: errors have delayed the completion of jobs, but the errors may be recoverable
  # * `FAILED`: unrecoverable errors prevented the completion of jobs
  #
  def show
    return unless @job_tracker
    respond_with(@job_tracker)
  end

  private
  def find_job_tracker
    id = params[:id]
    if JobTracker.exists?(id)
      @job_tracker = JobTracker.find(id)
    else
      render :json => { :error => 'no such entity' }, :status => 404
    end
  end
end
