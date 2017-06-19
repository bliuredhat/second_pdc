#
# This will not be needed once Bug 1076276 is done
#
desc "Add multi-product mapping. Specify PKG, SRC, DEST, DIST, WHO, and SUBSCRIBERS (comma separated) as env vars."
task :add_multi_prod_map => :environment do

  user_name    = ENV['WHO']  or raise "Please specify your user name with WHO=someuser"
  package_name = ENV['PKG']  or raise "Please specify package name with PKG=somepackage"
  dist_type    = ENV['TYPE'] or raise "Please specify TYPE=RHN or TYPE=CDN"
  src_name     = ENV['SRC']  or raise "Please specify origin channel or cdn repo with SRC=somedist"
  dest_name    = ENV['DEST'] or raise "Please specify destination channel or cdn repo with DEST=somedist"
  sub_names    = ENV['SUBSCRIBERS'] or ask_to_continue_or_cancel "No subscribers specified. Okay?"

  user = User.find_by_name(user_name) or raise "Can't find user #{user_name}!"
  package = Package.find_by_name!(package_name)
  subscribers = (sub_names||'').split(',').map{ |s| User.find_by_name(s.strip) }

  # (Similar to DistHandler in lib/push/dist but never mind for now..)
  case dist_type when 'RHN'
    map_class = MultiProductChannelMap
    dist_class = Channel
    type_suffix = 'channel'
  when 'CDN'
    map_class = MultiProductCdnRepoMap
    dist_class = CdnRepo
    type_suffix = 'cdn_repo'
  else
    raise "Unknown dist type!"
  end

  src_dist = dist_class.find_by_name!(src_name)
  dest_dist = dist_class.find_by_name!(dest_name)

  ActiveRecord::Base.transaction do
    new_map = map_class.create!({
      "package" => package,
      "origin_#{type_suffix}" => src_dist,
      "destination_#{type_suffix}" => dest_dist,
      "origin_product_version" => src_dist.product_version,
      "destination_product_version" => dest_dist.product_version,
      "user" => user,
    })

    new_map.subscribers = subscribers
    new_map.reload

    puts ""
    puts "#{new_map.package.name} (#{dist_type})"
    puts "#{new_map.origin.name} (#{new_map.origin_product_version.name}) --> #{new_map.destination.name} (#{new_map.destination_product_version.name})"
    puts "Subscribers: #{new_map.subscribers.map{ |u| u.login_name }.join(", ")}"
    puts ""
    puts new_map.inspect
    puts ""

    raise "Rolling back" unless ask_for_yes_no("Commit the above?")
  end

end
