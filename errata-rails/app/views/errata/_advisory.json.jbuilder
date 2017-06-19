json.id advisory.id
json.type advisory.class.to_s
json.text_only advisory.text_only?
json.advisory_name advisory.advisory_name
json.synopsis advisory.synopsis
json.revision advisory.revision
json.status  advisory.status.to_s
json.security_impact advisory.security_impact

json.respin_count advisory.respin_count
json.pushcount advisory.pushcount
json.content_types advisory.content_types

json.timestamps do |t|
  t.issue_date advisory.issue_date
  t.update_date advisory.update_date
  t.release_date advisory.release_date
  t.status_time  advisory.status_updated_at
  t.created_at advisory.created_at
  t.updated_at advisory.updated_at
end

json.flags do |f|
  f.text_ready advisory.text_ready?
  f.mailed advisory.mailed?
  f.pushed advisory.pushed?
  f.published advisory.published?
  f.deleted advisory.deleted?
  f.qa_complete advisory.qa_complete?
  f.rhn_complete advisory.rhn_complete?
  f.doc_complete advisory.doc_complete?
  f.rhnqa advisory.rhnqa?
  f.closed advisory.closed?
  f.sign_requested advisory.sign_requested?
end

json.product do |prod|
  prod.id advisory.product.id
  prod.name advisory.product.name
  prod.short_name advisory.product.short_name
end

json.release do |r|
  r.id advisory.release.id
  r.name advisory.release.name
end

json.people do |u|
  u.assigned_to advisory.assigned_to.login_name
  u.reporter advisory.reporter.login_name
  u.qe_group  advisory.quality_responsibility.name
  u.docs_group advisory.docs_responsibility.name
  u.doc_reviewer advisory.doc_reviewer.login_name
  u.devel_group advisory.devel_responsibility.name
  u.package_owner advisory.package_owner.login_name
end

json.content do |c|
  c.topic       advisory.topic
  c.description advisory.description
  c.solution    advisory.solution
  c.keywords    advisory.keywords
end

json.batch do |b|
  b.id   advisory.batch.id
  b.name advisory.batch.name
  b.batch_blocker advisory.is_batch_blocker?
end if advisory.batch
