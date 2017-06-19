#
# See Bug 1007327
#
require 'test_helper'

class FixCPETest < ActionDispatch::IntegrationTest

  setup do
    @rhsa = RHSA.shipped_live.where(:text_only => 1).last
  end

  teardown do
    logout
  end

  test "do not allow editing non RHSAs" do
    auth_as secalert_user

    assert_form_shows_error(RHBA.new_files.last.id,
                            "has not been pushed to RHN Live yet")
    assert_form_shows_error(RHSA.shipped_live.where(:text_only => 0).last.id,
                            "is not a text only advisory.")
  end

  def assert_form_shows_error(advisory, error_message)
    visit "/errata/fix_cpe"

    fill_in "Advisory ID", :with => advisory
    click_on "Find Errata to Fix"

    assert has_content? error_message
  end

  test "fixes cpe successfully for RHSA" do
    expected =  "cpe:/a:redhat:jboss_enterprise_application_platform:5.1/jboss-remoting"
    auth_as secalert_user
    visit "/errata/fix_cpe"

    fill_in "Advisory ID", :with => @rhsa.id
    click_on "Find Errata to Fix"
    fill_in  "CPE Text", :with => expected

    # Ensure OVAL and XML and pushed to secalert
    Push::Oval.expects(:push_oval_to_secalert).once.with(@rhsa)
    Push::ErrataXmlJob.expects(:enqueue).once.with(@rhsa)

    click_on "Apply"

    assert_equal 200, page.status_code

    @rhsa.reload
    assert_match /CPE text changed/, @rhsa.comments.last.text
    assert_equal expected, @rhsa.content.text_only_cpe
  end

  test "non secalert can not use the form" do
    [qa_user, devel_user, releng_user].each do |user|
      auth_as user

      visit "/errata/fix_cpe"

      assert has_no_content?("Errata Fixup - CPE")
      assert has_no_button? "Find Errata to Fix"
      assert has_content? "You do not have permission to access this resource."
      logout
    end
  end

  # Adding and editing is the same form, in fact the same operation.
  test "cpe management allows editing cpe text" do
    auth_as secalert_user
    variant = Variant.find(65)
    oldcpe = variant.cpe
    assert variant.cpe.present?

    change_cpe_for_variant(variant, 'this is a test')
    assert_not_equal oldcpe, variant.cpe
  end

  test "cpe management can remove cpe text" do
    auth_as secalert_user
    variant = Variant.find(65)
    assert variant.cpe.present?

    change_cpe_for_variant(variant, '')
    assert variant.cpe.empty?
  end

  def change_cpe_for_variant(variant, expected)
    visit "/security/cpe_management"
    form = page.find_by_id("edit_variant_#{variant.id}", visible: false)
    form.fill_in 'variant_cpe', :with => expected, visible: false
    form.click_on 'Update', visible: false

    variant.reload
    assert_equal expected, variant.cpe
  end
end
