class BuildGuard < StateTransitionGuard

  def transition_ok?(errata)
    ok = errata.text_only? || file_list_is_ok?(errata)
    if ok && errata.supports_multiple_product_destinations?
      return multi_product_file_list_is_ok?(errata)
    end
    ok
  end

  def ok_message(errata=nil)
    # FIXME: For case errata=nil case is serve for respresent
    # workflow rules page. this methods is serve two
    # different page logic, it should be decouple the logic in
    # further days.
    if errata.nil? || errata.brew_builds.any?
      return 'Builds added'
    end
    ''
  end

  def failure_message(errata=nil)
    return '' unless errata.present?
    messages = []
    if errata.brew_builds.none?
      messages << 'No builds in advisory'
    end
    maps = errata.build_mappings.for_rpms
    num = maps.without_product_listings.size
    if num > 0
      messages << "Missing #{ApplicationHelper.n_thing_or_things(num, 'product listing')}"
    end
    num_no_cf = maps.without_current_files.size
    if num_no_cf > 0
      messages << "Missing current files records for #{ApplicationHelper.n_thing_or_things(num_no_cf, 'build')}"
    end
    messages.concat(multi_product_file_list_problems(errata))
    messages.join(', ')
  end

  def test_type
    'mandatory'
  end

  private

  # Checks if the advisory's file list is ok. If any builds are present,
  # ensures the product listings and file lists are all ok
  def file_list_is_ok?(errata)
    errata.brew_builds.any? &&
    errata.build_mappings.for_rpms.without_product_listings.empty? &&
    errata.build_mappings.for_rpms.without_current_files.empty?
  end

  def multi_product_file_list_is_ok?(errata)
    multi_product_file_list_problems(errata).blank?
  end

  # Checks the ProductListingCache for all of the advisory's
  # mapped products, and reports if any are blank
  def multi_product_file_list_problems(errata)
    return [] unless errata.supports_multiple_product_destinations?
    problems = []
    errata.build_mappings.each do |m|
      mapped = MultiProductMap.mapped_product_versions(m.product_version, m.brew_build.package)
      map_problems = mapped.select do |pv|
        listing = ProductListingCache.find_by_product_version_id_and_brew_build_id(pv, m.brew_build)
        listing.nil? || listing.empty?
      end
      unless map_problems.empty?
        problems << "Build #{m.brew_build.nvr} has missing product listings for multi-product mapped product versions: " +
          map_problems.map(&:name).join(', ')
      end
    end
    problems
  end
end
