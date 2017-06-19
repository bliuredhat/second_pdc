require 'test_helper'

class ProductListingCacheTest < ActiveSupport::TestCase
  fixtures :product_listing_caches

  #
  # See Bug 983932.
  #
  # Added a migration to increase the size of the `cache` field
  # in ProductListingCache since it was too small to hold the texlive
  # product listing for RHEL-7.
  #
  test "very long product list" do

    # This is the super long product listing for RHEL-7 texlive that was
    # getting truncated. Don't want autotests to require brew so I have
    # saved the data to a file. Data was produced by doing the following:
    #   Brew.get_connection.getProductListings('RHEL-7', 278854).to_yaml
    product_listing = YAML.load(File.read("#{Rails.root}/test/data/brew/texlive_product_listing.yml"))

    # The particular build and version for this test don't matter, but
    # shouldn't already have a ProductListingCache
    brew_build = BrewBuild.find(368626)
    product_version = ProductVersion.find(272)

    # (Previously the cache field would have been truncated since
    # product_listing is bigger than a mysql 'text' field).
    ProductListingCache.create!(
      :product_version => product_version,
      :brew_build      => brew_build,
      :cache           => product_listing.to_yaml
    )

    # Read it back to make sure we've round tripped via mysql
    product_listing_cache = ProductListingCache.last

    # Sanity check
    assert product_listing_cache
    assert_equal brew_build, product_listing_cache.brew_build
    assert_equal product_version, product_listing_cache.product_version

    # This would have failed before the bug 983932 fix.
    assert_equal product_listing.to_yaml.length, product_listing_cache.cache.length
    # This would have errored before the bug 983932 fix.
    assert_equal product_listing, YAML.load(product_listing_cache.cache)
  end

  test "verify uniqueness constraints" do
    c = ProductListingCache.last
    dup = ProductListingCache.new(:product_version => c.product_version, :brew_build => c.brew_build, :cache => {:foo => :bar}.to_yaml)
    refute dup.valid?
    assert_errors_include(dup, "Product version has already been taken")
    # check that even if we were to save without validation,
    # unique index is installed properly and prevents dups
    assert_raise(ActiveRecord::RecordNotUnique) { dup.save(:validate => false) }
  end

  test "test cache format" do
    bad_cache = ProductListingCache.new(:product_version => ProductVersion.last, :brew_build => BrewBuild.last, :cache => "Not a hash! HAHA".to_yaml)
    refute bad_cache.valid?
    assert_errors_include(bad_cache, "Cache not set as a Hash. It is a String")
  end

  test "has_errata" do
    assert ProductListingCache.find(1009215).has_errata?, "Product listing 1009215 is no longer mapping to any errata. This may cause by fixtures change."
    refute ProductListingCache.find(1009214).has_errata?, "Product listing 1009214 is mapping to at least one erratum. This may cause by fixtures change."
  end

  test "get product listing cache" do
    errata = Errata.find_by_advisory("RHSA-2014:2021")

    mappings = errata.errata_brew_mappings

    assert_listings_equal(mappings)

    # do caching now
    product_versions= mappings.map(&:product_version)
    brew_builds = mappings.map(&:brew_build)
    Thread.current[:cached_listings] = ProductListingCache.prepare_cached_listings(product_versions, brew_builds)

    # never do database query again
    ProductListingCache.expects(:find_by_product_version_id_and_brew_build_id).never
    assert_listings_equal(mappings)
  end

  def assert_listings_equal(mappings)
    mappings.each do |mapping|
      pv = mapping.product_version
      bb = mapping.brew_build
      expected = ProductListingCache.where(:product_version_id => pv, :brew_build_id => bb).first.get_listing
      actual = ProductListing.find_or_fetch(pv, bb, {:cache_only => true})
      assert_equal expected, actual
    end
  end
end
