require 'test_helper'

class FiledBugTest < ActiveSupport::TestCase

  test "invalid if advisory not in NEW_FILES state" do
    RHBA.any_instance.stubs(:new_record?).returns(false)
    RHBA.any_instance.stubs(:status).returns(State::QE)
    Bug.any_instance.stubs(:is_security_restricted?).returns(false)
    #
    # Don't check all other potential problems with this bug. We only
    # want to test :advisory_state_ok here
    #
    FiledBug.any_instance.stubs(:bug_valid).returns(true)

    refute FiledBug.new(:bug => Bug.first, :errata => RHBA.new()).valid?
  end

  test "invalid if security bug in non-RHSA" do
    Bug.any_instance.stubs(:is_security?).returns(true)
    FiledBug.any_instance.stubs(:bug_valid).returns(true)

    fb = FiledBug.new(:bug => Bug.first, :errata => RHBA.last)
    refute fb.valid?
    assert_equal 1, fb.errors.count
  end

  def multiple_filed_bug_rhsa_test(opts = {})
    e = opts[:errata] || RHSA.find(10893)
    who = opts[:who]
    expect_valid = opts[:expect_valid]

    e_other = RHSA.find(11056)
    bug = Bug.find(693796)

    # bug should have been filed on other advisory already, not target advisory
    assert e_other.bugs.include?(bug), 'fixture problem'
    refute e.bugs.include?(bug),       'fixture problem'

    # flags and ACL are irrelevant for this test, make them be OK
    release = e.release
    bug.update_attributes!(:flags => release.blocker_flags.map{|x| "#{x}+"}.join(','))
    release.class.any_instance.stubs(:supports_component_acl? => false)

    fb = FiledBug.new(:bug => bug, :errata => e, :who => who)

    if expect_valid
      assert_valid fb
    else
      refute fb.valid?
      assert_equal(
        'Bug #693796 The bug is filed already in RHSA-2011:11056.',
        fb.errors.full_messages.join)
    end
  end

  test 'secalert user can file bug on multiple RHSA' do
    multiple_filed_bug_rhsa_test :who => secalert_user, :expect_valid => true
  end

  test 'non-secalert user can file bug on multiple RHSA' do
    multiple_filed_bug_rhsa_test :who => devel_user, :expect_valid => true
  end

  test 'secalert user cannot file bug on RHBA if already filed on RHSA' do
    multiple_filed_bug_rhsa_test :errata => RHBA.find(16397), :who => secalert_user, :expect_valid => false
  end

  test 'non-secalert user cannot file bug on RHBA if already filed on RHSA' do
    multiple_filed_bug_rhsa_test :errata => RHBA.find(16397), :who => devel_user, :expect_valid => false
  end
end
