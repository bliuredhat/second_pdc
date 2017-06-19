json.id repo.id
json.type repo.type
json.release_type repo.release_type
json.name repo.name
json.has_stable_systems_subscribed repo.has_stable_systems_subscribed
json.variant do |v|
  v.id repo.variant.id
  v.name repo.variant.name
end
json.arch do |a|
  a.id repo.arch.id
  a.name repo.arch.name
end
