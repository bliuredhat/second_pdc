require 'test_helper'

class CreateVariantTest < ActionDispatch::IntegrationTest

  #
  # Primarily testing that can create a variant with a blank rhel
  # variant, (see bug 1034328). It could have been done as a
  # functional test or even a unit test, but let's do it here as
  # an integration test so we are also testing the form and some
  # other aspects of the UI from a higher level.
  #
  test "can create a variant with blank rhel variant" do
    # Pick a product version (from fixture data) to test with
    pv_name = 'RHEL-6.2-EUS'
    pv = ProductVersion.find_by_name(pv_name)
    assert pv, "can't find #{pv_name}"

    # Start on the product version page and click New Variant
    auth_as admin_user
    visit product_product_version_url(pv.product, pv)
    # New variant link at the side bar
    click_on 'new_variant'
    assert_equal 200, page.status_code
    assert page.
      find(:xpath, "//span[@class='short-name']").
      has_content?("New Variant for Product Version '#{pv_name}'")

    # Fill out form (with blank rhel variant selected)
    variant_name = 'INVALID_VARIANT_NAME'
    select '', :from => 'variant_rhel_variant_id'
    fill_in 'variant_name', :with => variant_name
    fill_in 'variant_description', :with => "bar"
    fill_in 'variant_cpe', :with => "baz"

    # Create it
    click_button 'Create'

    assert_equal 200, page.status_code
    # Should fail here because the tps_stream field is not filled and
    # ET failed to compute the tps_stream by the entered variant name
    assert page.has_text? "prohibited this variant from being saved"
    assert page.has_text? "Tps stream cannot be determined. Please make sure 'INVALID_VARIANT_NAME' is a valid variant name."

    # We now enter a tps stream for it and click create again
    fill_in 'variant_tps_stream', :with => "RHEL-6-Main-Server"
    click_button 'Create'
    assert_equal 200, page.status_code

    # See if it was really created
    new_variant = pv.variants.last

    assert page.find(:xpath, "//span[@class='short-name']").has_content?(variant_name)
    refute page.has_text? "prohibited this variant from being saved"
    assert_equal product_version_variant_path(pv, new_variant), current_path

    assert new_variant
    assert_equal Variant.last, new_variant
    assert_equal variant_name, new_variant.name
    assert_equal 'bar', new_variant.description
    assert_equal 'baz', new_variant.cpe
    assert_equal 'RHEL-6-Main-Server', new_variant.tps_stream

    # When you leave rhel variant blank it gets set to itself
    assert_equal new_variant.rhel_variant, new_variant
  end

end
