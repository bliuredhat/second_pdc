require 'test_helper'

class BugMessagingTest < ActiveSupport::TestCase

  setup do
    @rhba = RHBA.new_files.first
  end

  def bug_list(advisory)
    BugList.new(advisory.bugs.map(&:id).join(','), advisory)
  end

  test "adding bug sends a message" do
    list = bug_list(@rhba)
    (topic, message, properties) = message_generated_by do
      list.append(1230395)
      list.save!
    end

    assert_equal 'errata.bugs.changed', topic
    assert_equal({
      'added' => [{"id": 1230395, "type": "RHBZ"}].to_json,
      'dropped' => [].to_json,
    }, message.slice('added', 'dropped'))
  end

  test "removing bug sends a message" do
    advisory = RHBA.find(10808)
    list = bug_list(advisory)

    bug_id = advisory.bugs.last.id
    (topic, message, properties) = message_generated_by do
      list.remove(bug_id)
      list.save!
    end

    assert_equal 'errata.bugs.changed', topic
    assert_equal({
      'added' => [].to_json,
      'dropped' => [{"id": bug_id, "type": "RHBZ"}].to_json,
    }, message.slice('added', 'dropped'))
  end

  def message_generated_by(&block)
    jobs = capture_delayed_jobs(/SendMsgJob/) { yield }

    assert_equal 1, jobs.count
    send_msg_job = jobs.first

    topic = send_msg_job.instance_variable_get(:@topic)
    message = send_msg_job.instance_variable_get(:@message)
    properties = send_msg_job.instance_variable_get(:@properties)
    [topic, message, properties]
  end
end