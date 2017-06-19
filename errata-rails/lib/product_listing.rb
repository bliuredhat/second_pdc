#
# This is specific to ComposeDB product listings fetched from Brew.
# See also lib/pdc_product_listing for PDC based product listings.
#
module ProductListing

  def self.build_product_listing_iterator(listing_options={})
    file_select = listing_options.fetch(:file_select, Predicates.true)
    product_version = listing_options[:product_version]
    brew_build = listing_options[:brew_build]

    version_rhel_map = product_version.version_rhel_map
    listings = self.find_or_fetch(
      product_version, brew_build, listing_options.merge(
        :include_multi_product_mappings => false))

    # We group by everything except arch, because the consumers are
    # designed to recieve a list of arches rather than one arch at a
    # time.  It seems odd - in fact, most of the consumers just
    # iterate over the arch list as well - but I'm not keen to change
    # it.
    listings.
      group_by{|l| [l.variant_label, l.brew_file]}.
      each do |(variant_label,brew_file),file_listings|

      next unless file_select.call(brew_file)

      rhel_version = product_version.rhel_version_number + variant_label
      variant = version_rhel_map[rhel_version]
      next unless variant

      yield(brew_file, variant, brew_build, file_listings.map(&:destination_arch))
    end
  end

  def self.find_or_fetch(product_version, brew_build, options = {})
    out = self._find_or_fetch(product_version, brew_build, options)

    # If there are relevant multi-product mappings, make sure to fetch
    # listings for those mapped product versions as well.  They'll be
    # needed when the mappings are processed later.
    #
    # It's not strictly required to fetch them now, and we don't
    # return the values, but it's a good idea to try fetching now so
    # that:
    #
    # - product listings debug UI can show which listings are required
    #   due to multi-product mappings.
    #
    # - the relatively slow product listings fetch happens
    #   preemptively _now_ and not during the first request which
    #   happens to need them.
    #
    if options.fetch(:include_multi_product_mappings, true)
      MultiProductMap.mapped_product_versions(product_version, brew_build.package).
        each do |pv|
        # Empty listings are tolerated here.  We don't know whether
        # the multi-product listings will end up being used and we
        # should not block errata which don't use them.
        ProductListing._find_or_fetch(pv, brew_build, options.merge(
            :what_suffix => " [multi-product mapping for #{pv.name}]",
            :allow_empty => true))
      end
    end

    out
  end

  #
  # This may help write more readable code where we have an is_pdc
  # bool available already.
  #
  # For example, this:
  #   ProductListing.for_pdc(@is_pdc).find_or_fetch(...)
  #
  # Instead of this:
  #
  #   if @is_pdc
  #     PdcProductListing.find_or_fetch(...)
  #   else
  #     ProductListing.find_or_fetch(...)
  #   end
  #
  def self.for_pdc(is_pdc)
    is_pdc ? PdcProductListing : self
  end

  private

  def self._find_or_fetch(product_version, brew_build, options = {})
    use_cache = options.fetch(:use_cache, true)
    cache_only = options.fetch(:cache_only, false)
    save = options.fetch(:save, true)
    options = options.dup
    options[:trace] ||= lambda { |msg| BREWLOG.debug(msg) }
    options[:around_filter] ||= lambda{|what,&block| block.call() }
    if suffix = options[:what_suffix]
      filt = options[:around_filter]
      options[:around_filter] = lambda{|what,&block|
        filt.call("#{what}#{suffix}", &block)}
    end

    cached = ProductListingCache.cached_listing(product_version, brew_build)

    if (use_cache && cached) || cache_only
      return cached ? cached.get_listing : {}
    end

    listings = [
      get_brew_product_listings(product_version, brew_build, options),
      get_manifest_api_product_listings(product_version, brew_build, options),
    ].inject(&:deep_merge)

    if !options[:allow_empty] && listings.empty?
      return listings
    end

    if !cached
      cached = ProductListingCache.new(
        :product_version => product_version,
        :brew_build => brew_build)
    end

    out = ProductListingCache.to_flat_listing(brew_build, listings)
    cached.set_listing(out)
    if save
      cached.save!
    end

    out
  end

  def self.listings_match(first, second)
    return false unless first && second && first.length == second.length

    sort_func = lambda{|l| [
      l.variant_label,
      l.destination_arch.name,
      l.brew_file
    ]}

    return first.sort_by(&sort_func) == second.sort_by(&sort_func)
  end

  def self.listings_empty?(listings)
    # listings should be a hash
    listings.empty?
  end

  def self.listings_present?(listings)
    !listings_empty?(listings)
  end

  private

  def self.get_manifest_api_product_listings(product_version, brew_build, options)
    return {} unless Settings.manifest_api_enabled && Settings.manifest_api_url

    self.get_product_listings_by(product_version, brew_build, options[:trace]) do |product_label,brew_build|
      uri = URI.join(Settings.manifest_api_url + '/', "composedb/get-product-listings/#{product_label}/#{brew_build.nvr}")

      data = options[:around_filter].call("GET #{uri}") do
        Net::HTTP.start(uri.host, uri.port) do |http|
          response = http.get(uri.path, {'Accept' => 'application/json', 'User-Agent' => "ErrataTool/#{SystemVersion::VERSION} Ruby"})
          # Treat 404 as an absence of listings - it makes testing
          # easier.  Any other kind of error will be raised.
          if response.code == '404'
            {}
          else
            response.value  # raises if not successful
            JSON.parse(response.body)
          end
        end
      end

      self.extract_archive_listings_from_manifest_api(data)
    end
  end

  def self.extract_archive_listings_from_manifest_api(data)
    # We have a structure like this:
    # {
    #    'build': ...,
    #    'product': 'RHEL-6-Server-RHEV-S-3.4',
    #    'variants': {
    #        'RHEV-S-3.4': {
    #            'rpms': ...,
    #             'archives': {
    #                 '698266': {
    #                    'path': '/brewroot/packages/spice-client-msi/3.4/4/win/SpiceX_x64.cab',
    #                    'destination_arches': ['x86_64'],
    #                 },
    #                 '698268': {
    #                    'path': '/brewroot/packages/spice-client-msi/3.4/4/win/SpiceX_x86.cab',
    #                    'destination_arches': ['i386','x86_64'],
    #                 },
    #                 ...
    #
    # We want to extract the archives only, and return them
    # in this format:
    #
    # {
    #   "RHEV-S-3.4": {
    #     698266: ["x86_64"],
    #     698268: ["i386","x86_64"],
    #   ...
    #
    out = {}
    data.fetch('variants', {}).each do |variant,variant_data|
      variant_data.fetch('archives', {}).each do |id_str, archive|
        out[variant] ||= {}
        out[variant][id_str.to_i] = archive['destination_arches']
      end
    end
    out
  end

  def self.get_brew_product_listings(product_version, brew_build, options)
    begin
      self.get_product_listings_by(product_version, brew_build, options[:trace]) do |product_label,brew_build|
        what = "Brew getProductListings(\"#{product_label}\", #{brew_build.try(:id) || brew_build})"
        options[:around_filter].call(what) do
          begin
            Brew.get_connection(false).getProductListings(product_label,brew_build.id)
          rescue Exception => e
            options[:trace].call("#{what}: #{e.class}: #{e.message}")
            raise
          end
        end
      end

    # Regarding the rescue blocks below here, note that they're outside of the
    # get_product_listings_by loop, i.e. the loop terminates as soon as any
    # error occurs.
    #
    # This means, for split product listings, if any one of the product labels
    # results in an error, we stop on the first failure and throw away any data
    # we may have fetched already.  This ensures we'll store complete product
    # listings or none at all.
    rescue XMLRPC::FaultException => e
      case e.to_s
      when
        # This particular error is tolerated and simply means we don't
        # store any product listings.
        # Brew is not expected to report product listings for non-RPMs.
        %r{Could not find any RPMs for build},
        # This happens when the product label has not yet been created.
        # Let's similarly not raise an error and not store any listings.
        %r{Could not find a product with label}
        options[:trace].call("Ignoring get_product_listings failure for #{brew_build}: #{e.inspect}")
        {}
      else
        # rethrow anything else
        raise
      end
    rescue Timeout::Error => te
      # Also tolerate timeout error. This could cause by slow composeDB and
      # we don't want to block user to add the build to an advisory. The build
      # can be refreshed by user later on.
      options[:trace].call("get_product_listings for #{brew_build} timeout")
      {}
    end
  end

  def self.get_product_listings_by(product_version, brew_build, trace)
    unless product_version.has_split_product_listings?
      trace.call("Using unified product listings for #{product_version.name} and build #{brew_build.nvr}")
      return yield(product_version.name, brew_build)
    end

    products = product_version.product_mapping
    trace.call("Using split product listings #{products.values.join(', ')} for build #{brew_build.nvr}")

    listings = Hash.new
    products.sort.each do |key,prod|
      orig_list = yield(prod, brew_build)
      orig_list.each do |version, archmap|
        version = "#{key}-"+ version unless version == key
        listings[version] = archmap
        # Ensure uniqueness of arch values in map
        archmap.values.select{|x| x.kind_of?(Hash)}.each{|arch| arch.values.each { |v| v.uniq! } }
      end
    end

    listings
  end
end
