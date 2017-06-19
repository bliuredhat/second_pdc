require 'test_helper'

class JiraPrivateOnlyFiledTest < ActiveSupport::TestCase
  assert_no_error_logs

  def file_issue_test(args)
    Settings.jira_private_only = args[:jira_private_only]
    e = Errata.find(10808)
    issue = JiraIssue.find_by_key!(args[:issue])
    assert_equal args[:issue_is_private], issue.is_private?, "fixture problem: wrong is_private? value on #{issue.key}"

    filed = FiledJiraIssue.new(
      :errata => e,
      :jira_issue => issue
    )

    if args[:expected_valid]
      assert_valid filed
    else
      refute filed.valid?
    end
  end

  test "cannot add public JIRA issue when jira_private_only" do
    file_issue_test(
      :jira_private_only => true,
      :issue => 'MAITAI-1210',
      :issue_is_private => false,
      :expected_valid => false)
  end

  test "can add public JIRA issue when not jira_private_only" do
    file_issue_test(
      :jira_private_only => false,
      :issue => 'MAITAI-1210',
      :issue_is_private => false,
      :expected_valid => true)
  end

  test "can add private JIRA issue when jira_private_only" do
    file_issue_test(
      :jira_private_only => true,
      :issue => 'UCD-132',
      :issue_is_private => true,
      :expected_valid => true)
  end

  test "can add private JIRA issue when not jira_private_only" do
    file_issue_test(
      :jira_private_only => false,
      :issue => 'UCD-132',
      :issue_is_private => true,
      :expected_valid => true)
  end
end

class JiraPrivateOnlyPushTest < ActiveSupport::TestCase
  assert_no_error_logs

  def assert_can_push(expected, target, e)
    actual = e.can_push_to?(target)
    blockers = e.push_blockers_for(target).join(', ')

    if expected
      assert_equal expected, actual,
        "Expected #{target} push to succeed, but it failed with blockers: #{blockers}"
    else
      assert_equal expected, actual, "Expected #{target} push to fail, but it succeeded."

      # Verify it was blocked for the right reason (but not CDN - it is "special" due to RHN&CDN push together logic)
      unless target.to_s =~ %r{cdn}i
        assert blockers.include?("Can't ship with public JIRA issues"),
          "Expected #{target} push to be blocked due to public JIRA issues, but blockers were: #{blockers}"
      end
    end
  end

  def push_issue_test(args)
    Settings.jira_private_only = args[:jira_private_only]
    e = Errata.find(10836)  # push-ready, CDN and RHN
    issue = JiraIssue.find_by_key!(args[:issue])
    assert_equal args[:issue_is_private], issue.is_private?, "fixture problem: wrong is_private? value on #{issue.key}"

    filed = FiledJiraIssue.new(
      :errata => e,
      :jira_issue => issue,
      :who => User.current_user,
      :state_index => e.current_state_index
    )
    # bypass validation to hack the issue in despite push-ready
    filed.save!(:validate => false)

    e.reload

    assert_can_push args[:expected_success], :rhn_live, e
    assert_can_push args[:expected_success], :cdn_if_live_push_succeeds, e
  end

  test "cannot push advisory with public JIRA issues when jira_private_only" do
    push_issue_test(
      :jira_private_only => true,
      :issue => 'MAITAI-1210',
      :issue_is_private => false,
      :expected_success => false)
  end

  test "can push advisory with public JIRA issues when not jira_private_only" do
    push_issue_test(
      :jira_private_only => false,
      :issue => 'MAITAI-1210',
      :issue_is_private => false,
      :expected_success => true)
  end

  test "can push advisory with private JIRA issues when jira_private_only" do
    push_issue_test(
      :jira_private_only => true,
      :issue => 'UCD-132',
      :issue_is_private => true,
      :expected_success => true)
  end

  test "can push advisory with private JIRA issues when not jira_private_only" do
    push_issue_test(
      :jira_private_only => false,
      :issue => 'UCD-132',
      :issue_is_private => true,
      :expected_success => true)
  end
end

class JiraPrivateOnlyViewsTest < ActionController::TestCase
  tests ErrataController
  assert_no_error_logs

  setup do
    @errata = Errata.find(7517)
    @issue = JiraIssue.find_by_key!('RHOS-504')
    refute @issue.is_private?, 'fixture problem: issue is expected to be public'
    assert @errata.jira_issues.include?(@issue), 'fixture problem: issue is not associated with advisory'
    auth_as devel_user
  end

  def view_test(args)
    Settings.jira_private_only = args[:jira_private_only]
    text = if args[:action].kind_of?(Symbol)
      get args[:action], args.slice(:format).merge(:id => @errata)
      assert_response :success, response.body
      response.body
    else
      args[:action].call().to_s
    end
    assert_equal args[:expected_visible], text.include?(@issue.key)
  end

  test "cannot display issue in advisory text when jira_private_only" do
    view_test(:jira_private_only => true, :action => :show_text, :expected_visible => false)
  end

  test "can display issue in advisory text when not jira_private_only" do
    view_test(:jira_private_only => false, :action => :show_text, :expected_visible => true)
  end

  test "cannot display issue in advisory XML when jira_private_only" do
    view_test(:jira_private_only => true, :action => :show_xml, :expected_visible => false)
  end

  test "can display issue in advisory XML when not jira_private_only" do
    view_test(:jira_private_only => false, :action => :show_xml, :expected_visible => true)
  end

  test "cannot display issue in advisory other XML when jira_private_only" do
    view_test(:jira_private_only => true, :action => :other_xml, :format => 'xml', :expected_visible => false)
  end

  test "can display issue in advisory other XML when not jira_private_only" do
    view_test(:jira_private_only => false, :action => :other_xml, :format => 'xml', :expected_visible => true)
  end

  test "cannot display issue in advisory RSS when jira_private_only" do
    view_test(:jira_private_only => true, :action => lambda{ ErrataRss.rss_for_errata(@errata.id) }, :expected_visible => false)
  end

  test "can display issue in advisory RSS when not jira_private_only" do
    view_test(:jira_private_only => false, :action => lambda{ ErrataRss.rss_for_errata(@errata.id) }, :expected_visible => true)
  end
end

class JiraPrivateOnlyNotifierTest < ActiveSupport::TestCase
  setup do
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []
    @errata = Errata.find(7517)
    @issue = JiraIssue.find_by_key!('RHOS-504')
    refute @issue.is_private?, 'fixture problem: issue is expected to be public'
    assert @errata.jira_issues.include?(@issue), 'fixture problem: issue is not associated with advisory'
  end

  def notify_test(args)
    Settings.jira_private_only = args[:jira_private_only]
    Notifier.partners_new_errata(@errata).deliver
    body = ActionMailer::Base.deliveries.last.body.to_s

    assert_equal args[:expected_visible], body.include?(@issue.key)
  end

  test "cannot display issue in partner mail when jira_private_only" do
    notify_test(:jira_private_only => true, :expected_visible => false)
  end

  test "can display issue in partner mail when not jira_private_only" do
    notify_test(:jira_private_only => false, :expected_visible => true)
  end
end
