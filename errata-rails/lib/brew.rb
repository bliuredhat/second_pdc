require 'xmlrpc/client'
require 'pp'
require 'yaml'

class Brew

  attr_accessor :errors

  def self.base_url
    @base_url ||= Settings.brew_base_url
  end

  def self.get_connection(unique = true)
    return Brew.new if unique
    @@rpc ||= Brew.new
  end

  def discard_old_package(errata, prod_ver_or_pdc_rel, package)
    # maps are errata_brew_mappings or pdc_errata_release_builds
    maps = old_maps_by_package(errata, prod_ver_or_pdc_rel)
    errata_brew_mappings = maps[package]
    errata_brew_mappings.each{ |m| m.obsolete! } if errata_brew_mappings
  end

  def old_maps_by_package(errata, prod_ver_or_pdc_rel)
    # Todo: rewrite these to use .current.where(...).includes(...) instead of find
    if errata.is_pdc?
      maps = errata.pdc_errata_release_builds.find(:all,
                                                   :conditions =>
                                                   ['current = 1 and pdc_release_id = ?',
                                                    prod_ver_or_pdc_rel],
                                                   :include => [:package, :brew_build])
    else
      maps = errata.errata_brew_mappings.find(:all,
                                              :conditions =>
                                              ['current = 1 and product_version_id = ?',
                                               prod_ver_or_pdc_rel],
                                              :include => [:package, :brew_build])
    end

    old = HashSet.new
    maps.each do |m|
      old[m.package] << m
    end
    return old
  end

  def old_builds_by_package(errata, prod_ver_or_pdc_rel)
    old_maps = old_maps_by_package(errata, prod_ver_or_pdc_rel)

    old_builds = Hash.new
    old_maps.each_pair { |pkg, maps| old_builds[pkg] = maps.first.brew_build }
    return old_builds
  end

  def get_valid_tags(errata, product_version)
    valid_tags = errata.release.brew_tags
    valid_tags = product_version.brew_tags if valid_tags.empty?
    valid_tags.collect { |t| t.name }
  end

  def build_is_properly_tagged?(errata, pv_or_pr, build)
    build_tags = build.tags(:brew => self)
    if errata.is_pdc?
      valid_tags = pv_or_pr.valid_tags
    else
      valid_tags = get_valid_tags(errata, pv_or_pr)
    end

    build_tags.each { |t| return true if valid_tags.include?(t)}

    @errors[build.nvr] << "does not have any of the valid tags: #{valid_tags.join(', ')}. " +
      "It only has the following tags: #{build_tags.join(', ')}."
    return false
  end

  # Utility method for getting a list of tags on a build.
  # Only need the names, not the extra info in hash
  def list_tags(build)
    tags = self.listTags(build.nvr)
    unless tags.is_a? Array
      msg = "Invalid tag data for #{build.nvr} from brew: #{tags.inspect}"
      Rails.logger.error msg
      raise msg
    end
    tags.collect! {|t| t['name']}
  end

  def method_missing(name, *args)
    ActiveSupport::Notifications.instrument('rpc_call.brew', :method => name, :arguments => args) do
      return @proxy.send(name, *args)
    end
  end

  def initialize
    @server = XMLRPC::Client.new2(Settings.brew_xmlrpc_url, nil, 120)
    @proxy = @server.proxy
    @errors = HashList.new
  end

  def errors_to_a
    self.errors.map{ |h, t| "#{h}: #{Array.wrap(t).join(', ')}" }
  end

  def errors_to_s
    self.errors_to_a.join(' ')
  end
end
