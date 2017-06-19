require 'test_helper'
require 'jira_issues_common_test'

class UpdateDirtyIssuesJobTest < ActiveSupport::TestCase
  include JiraIssuesCommonTest

  setup do
    # We run all delayed jobs during this test, so clean them first to
    # ensure no unrelated code runs
    Delayed::Job.delete_all
  end

  test "perform no dirty" do
    JiraIssue.expects(:batch_update_from_jql).never

    DirtyJiraIssue.delete_all
    Jira::UpdateDirtyIssuesJob.new.perform
  end

  test "dirty issue sync that succeeds partially" do
    # Clean all dirty JIRA issues before proceeding
    DirtyJiraIssue.delete_all
    jira_issues = JiraIssue.order("id_jira asc").limit(10).to_a
    test_rpc_jira_issues = prepare_dirty_jira_issues(jira_issues)

    hash_ref = has_entry(:validateQuery, false)

    test_cases = []

    # Case 1: Updated 4 bugs should work fine
    test_cases << { remaining_dirty_issues: 6, max_jira_issues_per_sync: 4 }
    JiraIssue.expects(:batch_update_search).with(jql(jira_issues[0..3]), hash_ref).returns(test_rpc_jira_issues[0..3])

    # Case 2: Didn't update any bug due to error so no change in remaining bugs
    test_cases << { remaining_dirty_issues: 6, max_jira_issues_per_sync: 3 }
    JiraIssue.expects(:batch_update_search).with(jql(jira_issues[4..6]), hash_ref).raises(RuntimeError)

    # Case 3: Partially updated some issues
    test_cases << { remaining_dirty_issues: 2, max_jira_issues_per_sync: 4 }
    JiraIssue.expects(:batch_update_search).with(jql(jira_issues[4..7]), hash_ref).returns(test_rpc_jira_issues[4..5])

    # Case 4: All bugs are updated, don't need to rerun the job
    test_cases << { remaining_dirty_issues: 0, max_jira_issues_per_sync: 4 }
    JiraIssue.expects(:batch_update_search).with(jql(jira_issues[8..9]), hash_ref).returns(test_rpc_jira_issues[8..9])

    test_cases.each do |test_case|
      Settings.max_jira_issues_per_sync = test_case[:max_jira_issues_per_sync]

      # Make sure only 1 delayed job is enqueued
      assert_job_count(1)

      run_all_delayed_jobs
      assert_equal test_case[:remaining_dirty_issues], DirtyJiraIssue.count
    end

    # Make sure the job is not rerun
    assert_job_count(0)
  end

  test "perform some dirty" do
    # Clean all dirty JIRA issues before proceeding
    DirtyJiraIssue.delete_all
    jira_issues = JiraIssue.order("id_jira asc").limit(10).to_a
    test_rpc_jira_issues = prepare_dirty_jira_issues(jira_issues)

    hash_ref = has_entry(:validateQuery, false)

    JiraIssue.expects(:batch_update_search).with(jql(jira_issues[0..3]), hash_ref).returns(test_rpc_jira_issues[0..3])
    JiraIssue.expects(:batch_update_search).with(jql(jira_issues[4..7]), hash_ref).raises(RuntimeError)
    JiraIssue.expects(:batch_update_search).with(jql(jira_issues[4..8]), hash_ref).returns(test_rpc_jira_issues[4..8])
    JiraIssue.expects(:batch_update_search).with(jql(jira_issues[9..9]), hash_ref).returns(test_rpc_jira_issues[9..9])

    test_cases = [
      # Case 1: Updated 4 bugs
      {:remaining_dirty_issues => 6, :max_jira_issues_per_sync => 4},
      # Case 2: Didn't update any bug due to error
      {:remaining_dirty_issues => 6, :max_jira_issues_per_sync => 4},
      # Case 3: 1 dirty bug left, since we can only update 5 bugs per sync.
      {:remaining_dirty_issues => 1, :max_jira_issues_per_sync => 5},
      # Case 4: All bugs are updated, don't need to rerun the job
      {:remaining_dirty_issues => 0, :max_jira_issues_per_sync => 5}
    ]

    test_cases.each do |test_case|
      Settings.max_jira_issues_per_sync = test_case[:max_jira_issues_per_sync]

      # Make sure only 1 delayed job is enqueued
      assert_job_count(1)

      run_all_delayed_jobs
      assert_equal test_case[:remaining_dirty_issues], DirtyJiraIssue.count
    end

    # Make sure the job is not rerun
    assert_job_count(0)
  end

  def jql(jira_issues)
    "id in (#{jira_issues.map(&:id_jira).sort.join ', '})"
  end

  def assert_job_count(number)
    job = Delayed::Job.where('handler like ?', '%Jira::UpdateDirtyIssuesJob%')
    assert_equal number, job.count
  end

  def prepare_dirty_jira_issues(jira_issues)
    test_rpc_jira_issues = []
    jira_issues.each do |jira_issue|
      DirtyJiraIssue.mark_as_dirty!(jira_issue.id_jira)
      test_rpc_jira_issues << to_test_rpc_issue(jira_issue, 5.minutes.ago)
    end
    test_rpc_jira_issues
  end
end
