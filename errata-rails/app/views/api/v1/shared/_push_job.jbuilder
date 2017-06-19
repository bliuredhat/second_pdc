json.id push_job.id

# This supports the case that a push job has no ID yet
# (e.g. dry-run mode).
# URL method would normally crash in that case.
if push_job.id
  json.url api_v1_erratum_push_url(push_job.errata, push_job)
end

json.errata(:id => push_job.errata_id)
json.pub_task(:id => push_job.pub_task_id)

json.log push_job.log
json.status push_job.status
json.options push_job.pub_options
json.pre_tasks push_job.pre_push_tasks.sort
json.post_tasks push_job.post_push_tasks.sort

json.target(:id => push_job.push_target.id, :name => push_job.push_target.name)
