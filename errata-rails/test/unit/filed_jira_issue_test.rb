require 'test_helper'
require 'jira/rpc'

class FiledJiraIssueTest < ActiveSupport::TestCase

  test "invalid if advisory not in NEW_FILES state" do
    RHBA.any_instance.stubs(:new_record?).returns(false)
    RHBA.any_instance.stubs(:status).returns(State::QE)
    JiraIssue.any_instance.stubs(:is_security_restricted?).returns(false)

    refute FiledJiraIssue.new(:jira_issue => JiraIssue.first, :errata => RHBA.new()).valid?
  end

  test "invalid if security bug in non-RHSA" do
    JiraIssue.any_instance.stubs(:is_security?).returns(true)

    filed = FiledJiraIssue.new(:jira_issue => JiraIssue.first, :errata => RHBA.last)
    refute filed.valid?
    assert_equal 1, filed.errors.count
  end

  test "invalid if issue already filed" do
    issue = JiraIssue.find_by_key!('MAITAI-1249')
    errata = RHBA.find(11119)

    # test issue should be filed already, but not on our test errata
    refute issue.errata.empty?
    refute issue.errata.include?(errata)

    filed = FiledJiraIssue.new(:jira_issue => issue, :errata => errata)
    refute filed.valid?
    assert_equal 1, filed.errors.count
    assert_equal ['The issue is filed already in RHBA-2008:0588.'], filed.errors['Issue MAITAI-1249']
  end

  %w{devel secalert releng}.each do |user|
    test "#{user} user may bypass issue already filed check for RHSA" do
      issue = JiraIssue.find_by_key!('MAITAI-1249')
      errata = RHSA.find(11149)

      # test issue should be filed already, but not on our test errata
      refute issue.errata.empty?
      refute issue.errata.include?(errata)

      test_user = instance_variable_get("@#{user}")
      filed = FiledJiraIssue.new(:jira_issue => issue, :errata => errata, :user => test_user)
      assert_valid filed
    end
  end

  test "invalid if public issue and Settings.jira_private_only is enabled" do
    issue = JiraIssue.unfiled.only_public.first
    errata = RHBA.new_files.first
    Settings.jira_private_only = true

    filed = FiledJiraIssue.new(:jira_issue => issue, :errata => errata)
    refute filed.valid?
    assert_equal 1, filed.errors.count
    assert_equal ['The issue is a publicly visible issue.  Only private issues may be used.'], filed.errors["Issue #{issue.display_id}"]
  end

  test "valid by default" do
    JiraIssue.any_instance.stubs(:is_security?).returns(false)

    filed = FiledJiraIssue.new(:jira_issue => JiraIssue.first, :errata => RHBA.find(16654))
    assert filed.valid?
  end

  test "comment posted" do
    force_sync_delayed_jobs(/Jira/) do
      e = RHBA.find(16654)
      filed = FiledJiraIssue.new(:jira_issue => JiraIssue.first, :errata => e)
      expected_comment = /This issue has been added to advisory #{Regexp.escape(e.advisory_name)} by /
      Jira::ErrataClient.any_instance.expects(:add_comment_to_issue).with(JiraIssue.first, regexp_matches(expected_comment), :private => true)
      filed.save!
    end
  end

end
