#
# This is specific to PDC based product listings for PDC advisories.
# See also lib/product_listing which is related to ComposeDB product
# listings for non-PDC advisories.
#
module PdcProductListing

  def self.find_or_fetch(pdc_release, brew_build, options={})
    use_cache = options.fetch(:use_cache, true)
    cache_only = options.fetch(:cache_only, false)
    save = options.fetch(:save, true)

    cached_listings = find_cached_listings(pdc_release, brew_build) if use_cache
    return cached_listings if cached_listings || cache_only

    live_listings = fetch_live_listings(pdc_release, brew_build)
    PdcProductListingCache.save_cached_listings(pdc_release, brew_build, live_listings) if save

    live_listings
  end

  def self.find_cached_listings(pdc_release, brew_build)
    PdcProductListingCache.find_cached_listings(pdc_release, brew_build)
  end

  def self.listings_empty?(listings)
    # listings should be either nil or an OpenStruct
    listings.nil? || listings.to_h.empty?
  end

  def self.listings_present?(listings)
    !listings_empty?(listings)
  end

  #
  # Fetch product listings through PDC api.
  #
  # Note that we get back Openstructs rather
  # than plain Hashes.
  #
  # Example response:
  #
  # {
  #   "compose": "RHCEPH-2.1-RHEL-7-20161208.t.1",
  #   "mapping": {
  #       "MON": {
  #           "x86_64": {
  #               "librgw2": [
  #                   "x86_64"
  #               ],
  #               "ceph-base": [
  #                   "x86_64"
  #               ],
  #               "libcephfs1-devel": [
  #                   "x86_64"
  #               ],
  #               "librbd1": [
  #                   "x86_64"
  #               ],
  #               "ceph": [
  #                   "src"
  #               ],
  #               ...
  #           }
  #       },
  #       "OSD": {
  #           "x86_64": {
  #               "librgw2": [
  #                   "x86_64"
  #               ],
  #               "ceph-base": [
  #                   "x86_64"
  #               ],
  #               "libcephfs1-devel": [
  #                   "x86_64"
  #               ],
  #               "librbd1": [
  #                   "x86_64"
  #               ],
  #               "ceph": [
  #                   "src"
  #               ],
  #               ...
  #           }
  #       }
  #   }
  # }
  #
  def self.fetch_live_listings(pdc_release, brew_build)
    response = begin
      PDC::V1::ReleaseRpmMapping.where(release_id: pdc_release.pdc_id, package: brew_build.package.name)
    rescue PDC::ResourceNotFound
      nil
    end

    # Indicates no listings
    return nil unless response

    # Listings data is here
    response.first.mapping
  end

end
