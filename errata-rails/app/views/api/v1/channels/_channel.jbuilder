json.attributes do
  json.extract! resource,
    :name,
    :use_for_tps

  json.release_type resource.short_type
end

json.relationships do
  json.arch resource.arch, :id, :name
  json.variants resource.links.map(&:variant).uniq, :id, :name
end
