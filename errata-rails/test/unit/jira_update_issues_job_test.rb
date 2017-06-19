require 'test_helper'
require 'jira_issues_common_test'

class JiraUpdateIssuesJobTest < ActiveSupport::TestCase
  include JiraIssuesCommonTest

  BASETIME = Time.now - 1.hour

  setup do
    # Override inspect to prevent infinite recursion.
    # Mocha calls inspect when formatting output messages,
    # which accesses the database, which calls Time.now,
    # which is mocked, causing mocha to call inspect, which ...
    JiraIssue.stubs(:inspect => 'JiraIssue(...)')
  end

  test 'perform' do
    job = Jira::UpdateIssuesJob.new

    (ok_issues, outdated_issues, new_issues) = prepare_issues
    dirty_issues = outdated_issues + new_issues
    all_rpc_issues = ok_issues + dirty_issues

    # Simulate that we last synced an hour ago
    Settings.jira_sync_timestamp = BASETIME
    duration = 1.hour
    now = BASETIME + duration
    Time.expects(:now).at_least_once.returns(now)

    time_range_in_minutes(now, duration).each do |range|
      JiraIssue.expects(:batch_update_search).with(jql(range[:from], range[:to]), instance_of(Hash)).returns(all_rpc_issues)
    end

    job.perform

    # Make sure the outdated issues and new issues are all marked as dirty
    assert_dirty_issues(dirty_issues)

    # The job should keep track of its last run time and search for issues updated since then
    from = Settings.jira_sync_timestamp
    duration = 142.minutes
    now += duration
    Time.expects(:now).at_least_once.returns(now)

    time_range_in_minutes(now, duration).each do |range|
      JiraIssue.expects(:batch_update_search).with(jql(range[:from], range[:to]), instance_of(Hash)).returns([])
    end

    job.perform

    # No dirty issue is marked
    assert_dirty_issues([])
  end

  def assert_dirty_issues(dirty_issues)
    dirty_issue_ids = dirty_issues.map(&:id).sort
    actual_dirty_issues = DirtyJiraIssue.where(:record_id => dirty_issue_ids)
    assert_equal dirty_issue_ids, actual_dirty_issues.map(&:id_jira).sort

    # Make sure their initial status are nil
    refute actual_dirty_issues.any?{|b| b.status != nil}
  end

  def jql(from_minutes, to_minutes)
    return "updated > -#{from_minutes}minutes AND updated <= #{to_minutes}minutes"
  end

  def prepare_issues
    issues = JiraIssue.limit(12)
    (ok_issues, outdated_issues) = to_rpc_issues(issues[0..9]).partition.with_index{|_,i| i.even?}

    # Fake new issues by deleting the existing issues
    new_issues = to_rpc_issues(issues[10..-1])
    issues[10..-1].map{ |issue| issue.delete }
    return ok_issues, outdated_issues, new_issues
  end

  test 'initial perform syncs a large set of issues' do
    now = Time.now
    Time.expects(:now).at_least_once.returns(now)

    checkpoint = 12.hours
    Settings.jira_sync_checkpoint = checkpoint

    assert_nil Settings.jira_sync_timestamp

    # Initial interval is large and arbitrarily picked
    time_range_in_minutes(now, 6.months, checkpoint).each do |range|
      JiraIssue.expects(:batch_update_search).with(jql(range[:from], range[:to]), instance_of(Hash)).returns([])
    end

    job = Jira::UpdateIssuesJob.new
    job.perform
  end

  def time_range_in_minutes(now, duration, checkpoint = 6.hour)
    # This method generates output like below:
    #[
    # {:from=>264965, :to=>264240},
    # {:from=>264245, :to=>263520},
    # {:from=>263525, :to=>262800},
    # {:from=>262805, :to=>262080},
    # {:from=>262085, :to=>261360},
    # {:from=>261365, :to=>260640},
    # ...
    # {:from=>1445, :to=>720},
    # {:from=>725, :to=>0}
    #]
    ranges = []
    to = nil
    begin
      from = to.nil? ? now - duration : to

      to = from + checkpoint

      from_minutes_diff = ((now - from) / 60).to_i + 5
      to_minutes_diff   = ((now - to) / 60).to_i

      if (to_minutes_diff > 0)
        to = to
      else
        to_minutes_diff = 0
        to = now
      end
      ranges << {:from => from_minutes_diff, :to => to_minutes_diff }
    end until(to == now)
    return ranges
  end

  def to_rpc_issues(issues)
    issues.map {|issue| to_test_rpc_issue(issue, BASETIME)}
  end
end
