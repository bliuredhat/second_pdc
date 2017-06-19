require 'test_helper'

class AddBugsToAdvisoryTest < ActionDispatch::IntegrationTest

  setup do
    @rhba = RHBA.new_files.last
    @rhsa = RHSA.new_files.last
    @new_bug = Bug.with_states(%w[NEW]).last
    # (For adding to an RHSA I think the bug should also be a
    # security bug. Todo: Should confirm that and test it).
  end

  def try_to_add_bug(errata, bug, expect, note)
    visit "/errata/edit/#{errata.id}"
    orig_bug_ids = page.find('#advisory_idsfixed').value
    fill_in 'advisory_idsfixed', :with => "#{orig_bug_ids} #{bug.id}"
    click_button 'Preview >'

    if expect == :disallow
      assert page.find('h1').has_content?('Edit Advisory'), "#{note} should not be allowed to add bug"
      assert page.has_content?("prohibited this advisory from being saved"), page.html
      refute Errata.find(errata.id).bugs.include?(Bug.find(bug.id))
    else # expect == :allow
      assert page.find('h1').has_content?('Preview'), "#{note} should be allowed to add bug"
      assert page.has_content?("To re-edit use your back button")
      click_button 'Save Errata'
      assert_match %r|/errata/details/#{errata.id}|, current_url, "didn't complete save after preview"
      assert errata.reload.bugs.include?(Bug.find(bug.id))
      comment = errata.comments.last
      assert_equal 'BugAddedComment', comment.type
      assert_match "bug #{bug.id}", comment.text
    end
  end

  test "devel user can't add ineligible bug to rhba or rhsa" do
    refute devel_user.is_kernel_developer?
    auth_as devel_user
    try_to_add_bug(@rhba, @new_bug, :disallow, 'devel user for rhba')
    try_to_add_bug(@rhsa, @new_bug, :disallow, 'devel user for rbsa')
  end

  test "secalert user can add ineligible bug to rhsa but not rhba" do
    auth_as secalert_user
    try_to_add_bug(@rhba, @new_bug, :disallow, 'secalert user for rhba')
    try_to_add_bug(@rhsa, @new_bug, :allow,    'secalert user for rhsa')
  end

  test "devel user can't add bug to rhsa unless he's a kernel developer" do
    assign_user_to_kernel_group(devel_user)
    assert devel_user.is_kernel_developer?
    auth_as devel_user
    try_to_add_bug(@rhba, @new_bug, :disallow, 'kernel dev for rhba')
    try_to_add_bug(@rhsa, @new_bug, :allow,    'kernel dev for rhsa')
  end

  test "secalert can add bug to multiple advisories" do
    auth_as secalert_user
    try_to_add_bug(@rhsa, RHSA.qe.last.bugs.first, :allow, 'secalert user, bug in other advisory')
  end

  test "devel user can't add bug to multiple advisories" do
    auth_as devel_user
    try_to_add_bug(@rhba, RHBA.qe.last.bugs.first, :disallow, 'devel user, bug in other advisory')
  end

end
