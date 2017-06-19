json.array!(@all_mappings.sort_by{|m| m.class.name}) do |m|
  json.id m.id

  type = @channel_mappings.include?(m) ? :rhn : :cdn

  json.type                           type

  if type == :rhn
    json.destination_channel          m.destination_channel.name
    json.destination_channel_id       m.destination_channel_id
    json.origin_channel               m.origin_channel.name
    json.origin_channel_id            m.origin_channel_id
  elsif type == :cdn
    json.destination_cdn_repo         m.destination_cdn_repo.name
    json.destination_cdn_repo_id      m.destination_cdn_repo_id
    json.origin_cdn_repo              m.origin_cdn_repo.name
    json.origin_cdn_repo_id           m.origin_cdn_repo_id
  end

  json.destination_product_version    m.destination_product_version.name
  json.destination_product_version_id m.destination_product_version_id
  json.origin_product_version         m.origin_product_version.name
  json.origin_product_version_id      m.origin_product_version_id

  json.package                        m.package.name
  json.package_id                     m.package_id
end
