require 'test_helper'

class ModifyCveTest < ActionDispatch::IntegrationTest

  setup do
    @rhsa = RHSA.find(11149)
  end

  def try_to_add_cve(errata, expect, note)
    visit "/errata/edit/#{errata.id}"
    orig_cves = page.find('#advisory_cve').value
    fill_in 'advisory_cve', :with => "#{orig_cves} CVE-2013-9876"
    click_button 'Preview >'
    if expect == :disallow
      assert page.find('h1').has_content?('Edit Advisory'), "#{note} should NOT have been allowed to edit the CVE"
      assert page.has_content?("Only Secalert or kernel developers can add or remove CVEs in an advisory")
      refute Errata.find(errata.id).cve_list.include?('CVE-2013-9876')
    else # expect == :allow
      assert page.find('h1').has_content?('Preview'), "#{note} should have been allowed to edit the CVE"
      refute page.has_content?("Only Secalert or kernel developers can add or remove CVEs in an advisory")
      click_button 'Save Errata'
      assert_match %r|/errata/details/#{errata.id}|, current_url, "didn't complete save after preview"
      assert Errata.find(errata.id).cve_list.include?('CVE-2013-9876')
    end
  end

  test "normal devel user can't add CVE to RHSA" do
    refute devel_user.is_kernel_developer?
    auth_as devel_user
    try_to_add_cve(@rhsa, :disallow, 'devel user')
  end

  test "kernel devel user can add CVE to RHSA" do
    assign_user_to_kernel_group(devel_user)
    assert devel_user.is_kernel_developer?
    auth_as devel_user
    try_to_add_cve(@rhsa, :allow, 'kernel devel user')
  end

  test "secalert user can add CVE to RHSA" do
    auth_as secalert_user
    try_to_add_cve(@rhsa, :allow, 'secalert user')
  end

end
