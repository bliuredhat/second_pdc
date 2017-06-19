require 'test_helper'
require 'test_messenger'

class JiraMessagingTest < ActiveSupport::TestCase

  test "don't crash on invalid message" do
    Settings.mbus_jira_sync_enabled = true
    test_jira_messages(['some garbage', 'not the right format'])
  end

  test "update and create mix" do
    Settings.mbus_jira_sync_enabled = true
    existing_ids = %w{25077 24260 24475}
    new_ids = %w{999991 999992 999993}
    all_ids = existing_ids + new_ids
    # cycle tests that we don't break on duplicates
    ids = all_ids.cycle(2).to_a

    # Clean all existing dirty JIRA issues before proceeding the test
    DirtyJiraIssue.delete_all

    test_jira_messages(
      ids.map{|id| {:id => id}.to_json}
    )

    # Out-dated existing JIRA issues should be marked as dirty
    JiraIssue.where(:id_jira => existing_ids).each do |jira_issue|
      assert jira_issue.dirty?
    end

    # and others should not have been created yet
    # but should be marked as dirty.
    new_ids.each do |id|
      refute JiraIssue.exists?(:id_jira => id)
      assert DirtyJiraIssue.exists?(:record_id => id)
    end

    assert_equal all_ids.length, DirtyJiraIssue.count
  end

  def test_jira_messages(bodies)
    address = 'queue://errata_from_esb'
    props = {'esbSourceSystem' => 'jbossJira',
             'esbMessageType' => 'jbossJiraNotification'}
    messages = bodies.map do |b|
      TestMessage.new(address, b, props)
    end
    TestMessenger.test_messages(messages)
  end

end
