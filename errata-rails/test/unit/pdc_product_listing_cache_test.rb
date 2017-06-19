require 'test_helper'

# This test also covers code in lib/product_listings/pdc.rb
class PdcProductListingCacheTest < ActiveSupport::TestCase

  setup do
    @errata = Errata.find(21131)
    @pdc_release = PdcRelease.get('ceph-2.1-updates@rhel-7')
    @brew_build = BrewBuild.find_by_nvr('ceph-10.2.3-17.el7cp')
  end

  test "caching behaviour works as expected" do
    listings = listings_data('ceph-2.1-ceph.yml')

    # Cached listing exists (because it is in fixtures).
    # No need to mock_live_listings yet since it should not be accessed.
    assert_no_difference 'PdcProductListingCache.count' do
      assert_equal listings, do_fetch
    end

    # Remove the listing cache record and prepare mock data
    PdcProductListingCache.find_by_pdc_release_id_and_brew_build_id(@pdc_release.id, @brew_build.id).delete
    mock_live_listings(@pdc_release, @brew_build, listings).times(3)

    # Next fetch should create a new cache record
    assert_difference('PdcProductListingCache.count') do
      assert_equal listings, do_fetch
    end

    # Let's edit the cached data manually so it's different to the live data
    modified_listings = OpenStruct.new(foo: 'bar')
    PdcProductListingCache.last.update_attributes!(cache: modified_listings)

    # Cache only fetch
    assert_equal modified_listings, do_fetch

    # Ignore cache entirely
    assert_equal listings, do_fetch(use_cache: false, save: false)
    assert_equal modified_listings, do_fetch

    # Update the cached value from live data
    assert_equal listings, do_fetch(use_cache: false)
    assert_equal listings, do_fetch

  end

  def do_fetch(opts={})
    ProductListing.for_pdc(true).find_or_fetch(@pdc_release, @brew_build, opts)
  end

  def mock_live_listings(pdc_release, brew_build, listings)
    PdcProductListing.
      expects(:fetch_live_listings).
      with(pdc_release, brew_build).
      returns(listings)
  end

  def listings_data(yaml_file)
    YAML.load(File.read(
      "#{Rails.root}/test/data/pdc_product_listing_cache/#{yaml_file}"))
  end

end
