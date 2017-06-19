require 'test_helper'

class CPEManagementTest < ActionDispatch::IntegrationTest

  setup do
    @index_page = "/security/cpe_management"
    admin_user.roles << Role.find_by_name('secalert')
  end

  test "products are linked" do
    auth_as admin_user
    visit @index_page
    first(:link, 'RHEL-2.1').click

    assert first('.item-title').has_content? 'RHEL'
    assert first('.item-title').has_content? 'Red Hat Enterprise Linux'
    assert first('.item-title').has_content? 'Product'
  end

  test "variants are linked" do
    auth_as admin_user
    variant = Variant.find_by_name('2.1AW')

    visit @index_page
    first(:link, variant.name).click

    assert page.find(:xpath, "//span[@class='short-name']").has_content?(variant.name)
    assert page.find(:xpath, "//span[@class='object-type']").has_content?("Variant")
    assert page.find(:xpath, "//span[@class='long-name']").has_content?(variant.description)
  end
end
