json.array! @products do |product|
  json.product_id             product.id
  json.product_short_name     product.short_name
  json.product_name           product.name
  json.brew_rpm_name_prefixes product.brew_rpm_name_prefix_strings
end
