json.attributes do
  json.name resource.name
end

json.relationships do
  json.devel_owner            resource.devel_owner, :id, :realname
  json.devel_responsibility   resource.devel_responsibility, :id, :name

  json.qe_owner               resource.qe_owner, :id, :realname
  json.quality_responsibility resource.quality_responsibility, :id, :name

  json.docs_responsibility    resource.docs_responsibility, :id, :name
  json.errata                 resource.errata, :id, :fulladvisory, :errata_type,
                                             :actual_ship_date, :status
end
