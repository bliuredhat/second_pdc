json.attributes do
  json.extract! resource, :tag_template
end

json.relationships do
  json.cdn_repo resource.cdn_repo_package.cdn_repo, :id, :name
  json.package resource.cdn_repo_package.package, :id, :name
  if resource.variant
    json.variant resource.variant, :id, :name
  end
end
