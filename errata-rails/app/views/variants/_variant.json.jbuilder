json.id variant.id
json.name variant.name
json.description variant.description
json.cpe variant.cpe
json.tps_stream variant.get_tps_stream
json.enabled variant.enabled
json.product do |prod|
  prod.id variant.product.id
  prod.short_name variant.product.short_name
end
json.product_version do |prod|
  prod.id variant.product_version.id
  prod.name variant.product_version.name
end
json.rhel_variant do |rv|
  rv.id variant.rhel_variant.id
  rv.name variant.rhel_variant.name
end
json.rhel_release do |r|
  r.id variant.rhel_release.id
  r.name variant.rhel_release.name
end
