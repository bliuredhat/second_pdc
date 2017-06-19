require 'test_helper'

class ProductVersionsTest < ActionDispatch::IntegrationTest

  test "warning if product version brew tags overridden by release" do
    auth_as admin_user

    pv = ProductVersion.find_by_name('RHEL-6')

    # This release has brew tags configured (that are not
    # the same as the brew tags for the product version)
    release1 = Release.find_by_name('RHEL-6.1.0')

    # This release does not have brew tags configured
    release2 = Release.find_by_name('FAST6.7')

    assert pv.releases.count == 2
    assert pv.releases.map(&:id).sort == [release1, release2].map(&:id).sort
    assert release1.product_versions.include? pv
    assert release1.brew_tags.any?
    assert release1.brew_tags.sort != pv.brew_tags.sort
    assert release2.brew_tags.none?

    # Warning shown on product version page
    visit "/products/#{pv.product_id}/product_versions/#{pv.id}"
    assert page.has_content?('Brew tags are configured')

    # Remove the tags from the release
    release1.brew_tags.delete_all
    refute release1.brew_tags.any?

    # No warning
    visit "/products/#{pv.product_id}/product_versions/#{pv.id}"
    refute page.has_content?('Brew tags are configured')

    # Make the release tags match the product version tags
    release1.brew_tags << pv.brew_tags
    assert release1.brew_tags.sort == pv.brew_tags.sort

    # No warning
    visit "/products/#{pv.product_id}/product_versions/#{pv.id}"
    refute page.has_content?('Brew tags are configured')
  end

end
