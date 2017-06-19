json.attributes do
  json.extract! resource,
      :name, :description,
      :type, :allow_pkg_dupes, :ship_date

  json.is_active resource.is_active?
  json.enabled resource.enabled?
  json.enable_batching resource.enable_batching?
  json.is_async resource.is_async?
  json.is_deferred resource.is_deferred?
  json.allow_shadow resource.allow_shadow?
  json.allow_blocker resource.allow_blocker?
  json.allow_exception resource.allow_exception?
  json.blocker_flags resource.blocker_flags
  json.is_pdc resource.is_pdc?
end

json.relationships do
  json.brew_tags resource.brew_tags, :id, :name
  if resource.is_pdc?
    json.pdc_releases resource.pdc_releases, :id, :pdc_id
  else
    json.product_versions resource.product_versions, :id, :name
  end
end
