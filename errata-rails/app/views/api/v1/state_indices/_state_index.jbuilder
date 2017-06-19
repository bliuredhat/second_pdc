json.attributes do
  json.errata_id resource.errata_id
  json.previous resource.previous
  json.current resource.current
  json.created_at resource.created_at
  json.who resource.who, :login_name, :realname
end
