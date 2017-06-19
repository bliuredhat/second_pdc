json.attributes do
  json.created_at resource.created_at
  json.errata_id resource.errata_id
  json.text resource.text
  json.who resource.who, :login_name, :realname
  json.advisory_state resource.state_index.try(:current)
end
