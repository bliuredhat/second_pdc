json.array! @mappings do |m|
  json.set!(:build, m.brew_build.attributes.slice('nvr', 'id'))
  json.set!(:product_version, m.product_version.attributes.slice('name', 'id'))
  json.file_type m.file_type_name
  json.flags m.flags.sort
end
