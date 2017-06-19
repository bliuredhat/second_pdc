json.job_tracker do
  json.extract! @job_tracker,
    :created_at,
    :description,
    :id,
    :max_attempts,
    :name,
    :state,
    :updated_at,
    :user_id,
    :total_job_count

  json.pending_jobs(@job_tracker.jobs.sort_by(&:id)) do |job|
    json.extract! job,
      :id,
      :run_at,
      :error

    # Fix up some inconsistencies which shouldn't leak to the API.
    json.state job.status
    json.name job.task_name
  end
end
