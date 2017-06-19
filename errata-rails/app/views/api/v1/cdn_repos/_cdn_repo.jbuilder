json.attributes do
  json.extract! resource,
    :name,
    :release_type,
    :use_for_tps

  json.content_type resource.short_type
  json.release_type resource.short_release_type
end

json.relationships do
  json.arch resource.arch, :id, :name
  json.variants resource.links.map(&:variant).uniq, :id, :name
  if resource.supports_package_mappings?
    json.packages resource.cdn_repo_packages.sort_by(&:id) do |c|
      json.id c.package.id
      json.name c.package.name
      json.cdn_repo_package_tags c.cdn_repo_package_tags.sort_by(&:id) do |pt|
        json.id pt.id
        json.tag_template pt.tag_template
      end
    end
  end
end
