json.id @job_tracker.id
json.name @job_tracker.name
json.description @job_tracker.description
json.jobs do
  json.partial! "/background_job/delayed_jobs", :jobs => @job_tracker.jobs
end
