json.attributes do
  json.name         resource.name
  json.is_active    resource.is_active?
  json.is_locked    resource.is_locked?
  json.description  resource.description
  json.release_date short_date(resource.release_date)
end

json.relationships do
  json.errata resource.errata, :id
  json.release resource.release, :id, :name
end
