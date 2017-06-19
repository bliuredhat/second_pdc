require 'test_helper'

class ProductListingTest < ActiveSupport::TestCase
  test 'missing product label in multi-product listings are tolerated' do
    build = BrewBuild.find_by_nvr!('sblim-cim-client2-2.1.3-2.el6')
    pv = ProductVersion.find_by_name!('RHEL-6')

    ProductListingCache.where(:brew_build_id => build).where('product_version_id != ?', pv).delete_all

    # We've deleted any ProductListingCache above for mapped products.
    #
    # We expect that has_valid_listing? does cause an attempt to
    # re-fetch that cache, but tolerates a missing product label.
    #
    # The missing product label should be cached, so calling twice should
    # only result in one fetch.
    expect_call = lambda do |label|
      Brew.any_instance.expects(:getProductListings).once.
        with(label, build.id).
        raises(XMLRPC::FaultException.new(1000, "Could not find a product with label: #{label}"))
    end

    # There are two product versions mapped via multi-product mappings;
    # RHEL-6-RHEV and RHEL-6-RHEV-S.  They use split product listings, but we
    # only query the first label on each of them, since split product listings
    # stops fetching at the first failure.
    #
    # Note this behavior was changed for bug 1296021.
    %w[
      RHEL-6-Client-RHEV
      RHEL-6-Server-RHEV-S
    ].each(&expect_call)

    check_valid = lambda do
      assert build.has_valid_listing?(pv)
    end
    check_valid.call()
    check_valid.call()
  end

  # Bug 1296021
  test 'split listings timeouts prevent populating the cache' do
    (build, pv) = set_up_split_listing_failure_test(Timeout::Error)

    # It should not create any cache object
    is_valid = nil
    assert_no_difference('ProductListingCache.count') do
      is_valid = build.has_valid_listing?(pv)
    end

    # It should not be considered valid, since some of the calls timed out
    refute is_valid
  end

  # Sets up fixtures and mocks for a "fetch split product listings" test, where
  # some of the split listing calls will succeed and others will fail with
  # +exception+.
  # Returns the build and product version to be used for the test.
  def set_up_split_listing_failure_test(exception)
    build = BrewBuild.find_by_nvr!('autotrace-0.31.1-26.el6')
    pv = ProductVersion.find_by_name!('RHEL-6')

    ProductListingCache.where(:brew_build_id => build).where('product_version_id = ?', pv).delete_all

    expect_call_and_raise = lambda do |label|
      Brew.any_instance.expects(:getProductListings).once.
        with(label, build.id).
        raises(exception)
    end

    expect_call_and_succeed = lambda do |label|
      Brew.any_instance.expects(:getProductListings).once.
        with(label, build.id).
        returns({label.gsub(/^RHEL-6-/, '') => {
                  'autotrace-0.31.1-26.el6' => {
                    'x86_64' => ['x86_64']}}})
    end

    expect_no_call = lambda do |label|
      Brew.any_instance.expects(:getProductListings).with(label, build.id).never
    end

    %w[
      RHEL-6-Client
      RHEL-6-ComputeNode
    ].each(&expect_call_and_succeed)

    %w[
      RHEL-6-Server
    ].each(&expect_call_and_raise)

    # Since server failed, it should stop before workstation
    %w[
      RHEL-6-Workstation
    ].each(&expect_no_call)

    [build, pv]
  end
end
