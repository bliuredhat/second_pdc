json.id @release.id
json.name @release.name
json.description @release.description
json.type @release.class.to_s
json.isactive @release.isactive?
json.is_async @release.is_async?
json.blocker_flags @release.blocker_flags
json.ship_date @release.ship_date.try(:to_s)
json.brew_tags @release.brew_tags.collect {|t| t.name}

unless @release.product.nil?
  json.product do |prod|
    prod.id @release.product.id
    prod.short_name @release.product.short_name
  end
end

json.product_versions @release.product_versions.collect {|v| {:id => v.id, :name => v.name}}
