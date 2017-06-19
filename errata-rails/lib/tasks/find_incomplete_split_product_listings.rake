namespace :find_incomplete_split_product_listings do

  def active_mappings
    # active mappings for RPMs since the bug was originally introduced
    # (may include shipped errata)
    ErrataBrewMapping.for_rpms.current.where('created_at >= "2015-08-04"').order('errata_id asc')
  end

  def check_mapping(m)
    mapping_pv = m.product_version
    # Needs to be checked for multi-product mappings as well
    all_pv = [mapping_pv] + MultiProductMap.mapped_product_versions(mapping_pv, m.brew_build.package)
    all_missing = all_pv.map do |pv|
      plc = ProductListingCache.cached_listing(pv, m.brew_build)
      log = lambda do |message|
        $stderr.puts "#{m.errata_id} - #{plc.try(:id)} - #{m.brew_build.nvr} - #{pv.name} - #{message}"
      end

      unless pv.has_split_product_listings?
        log['OK (unified)']
        next []
      end

      if plc.blank?
        log['OK (blank)']
        next []
      end

      have_variant_labels = plc.load_cache.map(&:first)

      # The debug map maps from brew input to possible brew output labels (to variants) e.g.
      #  {"RHEL-6.7.z-Client" => {"Client" => <Variant 6Client-6.7.z>,
      #                           "optional" => <Variant 6Client-optional-6.7.z>"}
      debug_map = ReleaseEngineeringController.new.send(:debug_product_listing_variant_map, pv, nil)

      # The inverted product mapping maps brew in$stderr.puts to the "base" variant label, e.g.
      # {"RHEL-6.7.z-Client" => "Client",
      #  "RHEL-6.7.z-ComputeNode" => "ComputeNode"}
      input_map = pv.product_mapping.invert

      # Iterate through every expected call to brew and check if the cache
      # contains any data as a result of that call.
      missing = debug_map.reject do |input_label, expected_response|
        # "Client"
        base_variant = input_map[input_label]

        # ["Client", "optional"]
        raw_labels = expected_response.map(&:first)

        # ["Client", "Client-optional"]
        # (This is what's actually stored in the cache)
        cached_labels = raw_labels.map do |label|
          if label == base_variant
            label
          else
            "#{base_variant}-#{label}"
          end
        end

        # So, if the cache includes any of the variant labels which could have
        # been stored by this brew response, we know this response was handled
        # correctly
        cached_labels.any?{ |label| have_variant_labels.include?(label) }
      end

      unless missing.any?
        log['OK (complete)']
        next []
      end

      # "missing" now contains each label passed to brew which we don't have any
      # data for. It is possible that we didn't store any data because brew
      # genuinely didn't return any, or it is possible that we didn't store any
      # data because brew timed out (bug 1296021)
      missing_str = missing.map(&:first).sort.join(', ')
      log["MAYBE BROKEN - no data for: #{missing_str}"]

      missing.map(&:first)
    end.inject(&:concat)

    if all_missing.any?
      [m, all_missing]
    end
  end

  def fetch_listing(label, build_id)
    attempt = 0
    begin
      Brew.get_connection(false).getProductListings(label, build_id)
    rescue XMLRPC::FaultException => e
      $stderr.puts "    #{e}"
      case e.to_s
      when
        %r{Could not find any RPMs for build},
        %r{Could not find a product with label}
        {}
      else
        raise
      end
    rescue Timeout::Error => te
      $stderr.puts "    #{te} (#{attempt})"
      attempt += 1
      if attempt < 5
        retry
      end
      raise
    end
  end

  def fetch_and_compare(mapping, missing, suffix)
    $stderr.puts "MAPPING #{mapping.id}: #{suffix}"

    build_id = mapping.brew_build_id

    # If brew returns non-empty data for any of the missing labels, that means
    # the data we have is incomplete.  (If it returns empty for everything, then
    # it's correct that the labels are "missing" in the cache.)
    missing.any? do |label|
      $stderr.puts "  #{label}:"
      have_data = fetch_listing(label, build_id).present?
      $stderr.puts "    #{have_data ? 'BAD - DATA IS PRESENT IN BREW AND ABSENT IN CACHE' : 'OK'}"
      have_data
    end
  end

  desc 'Find product listing caches incomplete due to bug 1296021'
  task :run => :environment do
    to_fetch = active_mappings.map do |m|
      check_mapping m
    end.compact

    $stderr.puts "\n============= COMPARING SUSPICIOUS RECORDS WITH BREW =================\n\n"

    total = to_fetch.count
    i = 0
    mappings = to_fetch.select do |mapping, missing|
      i += 1
      fetch_and_compare mapping, missing, "(#{i} / #{total})"
    end.map(&:first)

    $stderr.puts "\n============= THESE MAPPINGS NEED TO BE RELOADED! ====================\n\n"

    if mappings.empty?
      $stderr.puts '(...nothing!)'
    else
      mappings.sort_by(&:errata_id).each do |m|
        $stderr.puts "#{m.errata.id} - #{m.id} - #{m.product_version.name} - #{m.brew_build.nvr}"
      end
    end
  end

end
