require 'test_helper'

class BrewPreviewFilesTest < ActionDispatch::IntegrationTest

  setup do
    auth_as devel_user
  end

  test 'show notification where relevant product mappings exist' do
    Brew.any_instance.stubs(:build_is_properly_tagged? => true)

    e = Errata.find(20291)
    pv = ProductVersion.find_by_name('RHEL-6')

    # this build has multi-product mappings with RHEL-6
    relevant_build = BrewBuild.find_by_nvr('jasper-1.900.1-16.el6_6.2')
    assert MultiProductMap.mapped_product_versions(pv, relevant_build.package).any?
    # this build doesn't have multi-product mapping with RHEL-6
    irrelevant_build = BrewBuild.find_by_nvr('cronie-1.4.4-12.el6')
    assert MultiProductMap.mapped_product_versions(pv, irrelevant_build.package).none?

    # cache will be used for test rather than fetching by Brew.productListings
    [relevant_build.id, irrelevant_build].each do |build|
      assert ProductListingCache.where(:product_version_id => pv.id,
                                       :brew_build_id => build).any?
    end

    visit "/advisory/#{e.id}/builds"
    fill_in "pv_#{pv.id}", :with => [relevant_build.nvr, irrelevant_build.nvr].join("\n")
    click_on 'Find New Builds'

    # show notification when build is relevant to any multi-product mappings
    assert page.has_content? "Note: Due to multi-product mappings for jasper this build may also include contents for mapped product versions( RHEL-6-OSE-2.0, RHEL-6-OSE-2.1 and RHEL-6-OSE-2.2 ).
For more details please see advisory's Content tab after the build has been saved."
    refute page.has_content? "Note: Due to multi-product mappings for cronie this build may also include contents for mapped product versions( #{irrelevant_build.package.name}"
  end

  test 'page includes link to product listings' do
    Brew.any_instance.stubs(:build_is_properly_tagged? => true)
    e = Errata.find(11020)
    pv = ProductVersion.find_by_name('RHEL-6')
    build = e.brew_builds.first

    cache = ProductListingCache.where(:product_version_id => pv.id, :brew_build_id => build.id).first
    mock_listing = cache.get_listing

    ProductListing.expects(:find_or_fetch).at_least_once.with(){|pv,b,opts|
      pv == cache.product_version && b == cache.brew_build
    }.returns(mock_listing)

    visit "/advisory/#{e.id}/builds"
    assert page.has_link?('Listings'), 'A link to Listings should be present'

    click_on 'Listings'
    assert has_content?('Product Listings for'), 'Product listings should be shown'
  end
end
