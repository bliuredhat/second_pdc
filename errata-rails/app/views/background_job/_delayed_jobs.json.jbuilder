json.array! jobs do |j|
  json.id j.id
  json.priority j.priority
  json.next_run j.run_at
  json.status j.status
  json.task j.task_name
end
