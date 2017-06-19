json.array! @variants do |v_cpe, variants|
  json.cpe v_cpe.blank? ? nil : v_cpe

  json.variants variants.sort_by(&:name) do |variant|
    json.id variant.id
    json.name variant.name
    json.description variant.description
    json.live variant_is_live?(variant) && variant.has_cpe?
  end
end
