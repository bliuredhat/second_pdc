class PdcProductListingCache < ActiveRecord::Base
  serialize :cache, OpenStruct

  belongs_to :pdc_release
  belongs_to :brew_build

  def self.find_cached_listings(pdc_release, brew_build)
    find_by_pdc_release_id_and_brew_build_id(pdc_release.id, brew_build.id).try(:cache)
  end

  def self.save_cached_listings(pdc_release, brew_build, listings)
    transaction do
      find_or_create_by_pdc_release_id_and_brew_build_id!(
        pdc_release.id, brew_build.id).update_attributes!(cache: listings)
    end
  end

  def listings_empty?
    PdcProductListing.listings_empty?(cache)
  end

  def self.cached_listing(pdc_release, brew_build)
    # find listing cache from memory first if exists
    listings = ThreadLocal.get(:cached_listings)
    if listings && listings[pdc_release.id] && listings[pdc_release.id][brew_build.id]
      return listings[pdc_release.id][brew_build.id]
    end
    # otherwise look at the database
    cached = PdcProductListingCache.find_by_pdc_release_id_and_brew_build_id(pdc_release, brew_build)
    cached
  end

  def pdc_errata_release_builds
    PdcErrataReleaseBuild.current.
      joins(:pdc_errata_release).
      where(:brew_build_id => brew_build_id).
      where('pdc_errata_releases.pdc_release_id = ?', pdc_release_id)
  end

  def has_errata?
    pdc_errata_release_builds.any?
  end

end
