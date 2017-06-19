json.attributes do
  json.test_type        resource.external_test_type.name
  json.active           resource.active
  json.status           resource.status
  json.external_message resource.external_message
  json.external_status  resource.external_status
  json.external_id      resource.external_id
  json.created_at       resource.created_at
  json.updated_at       resource.updated_at
end

json.relationships do
  json.errata resource.errata, :id, :fulladvisory, :errata_type

  other = resource.superseded_by
  if other
    json.superseded_by do
      json.id        other.id
      json.status    other.status
      json.test_type other.external_test_type.name
    end
  end

  if resource.brew_build
    json.brew_build resource.brew_build, :id, :nvr
  end
end
