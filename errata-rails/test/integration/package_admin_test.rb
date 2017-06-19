require 'test_helper'

class PackageAdminTest < ActionDispatch::IntegrationTest

  setup do
    auth_as admin_user
  end

  test "add ftp exclusion for product" do
    visit "/package/show/#{Package.first.name}"
    assert first(:css, '.exclusion_form', visible: false).has_selector?(:css, 'select', visible: false)

    select "RHEL for SAP", from: 'ftp_exclusion_product_id', visible: false
    first(:css, '.exclusion_form', visible: false).click_on('Create', visible: false)

    assert find_link('RHEL for SAP')
  end

  test "docker advisories listed for product" do
    visit "/package/show/rhel-server-docker"
    assert page.has_content?("Active Errata:")

    ["RHBA-2016:21100", "RHBA-2016:21101"].each do |full_name|
      assert Errata.find_by_advisory(full_name).has_docker?
      assert page.has_content?(full_name)
    end
  end

  test "unique rows in package advisories" do
    visit "/package/show/rhel-server-docker"

    assert_equal 3, Errata.find(16396).build_mappings.count

    # Should be only 1 of these links not 3 (bug 1354328)
    assert_equal 1, page.all(:xpath, "//a[@href='/advisory/16396']").count
  end

end
