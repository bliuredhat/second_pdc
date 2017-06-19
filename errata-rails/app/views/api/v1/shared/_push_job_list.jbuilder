json.array!(push_jobs) do |pj|
  json.partial! '/api/v1/shared/push_job', :push_job => pj
end
