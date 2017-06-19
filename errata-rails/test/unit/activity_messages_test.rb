require 'test_helper'

class ActivityMessagesTest < ActiveSupport::TestCase

  test "changing state creates a send message job with expected activity message" do
    errata = Errata.find(16409)
    Time.stubs(:now => Time.utc(2015,3,12))

    (routing_key, message) = message_generated_by { errata.change_state!('NEW_FILES', devel_user) }

    assert_equal 'errata.activity.status', routing_key

    assert_equal({
      'from' => 'QE',
      'to' => 'NEW_FILES',
      'who' => 'qa-errata-list@redhat.com',
      'when' => '2015-03-12 00:00:00 UTC',
      'errata_id' => errata.id,
      'synopsis' => errata.synopsis,
      'fulladvisory' => errata.fulladvisory,
    }, message)
  end

  test 'changing state sends unembargoed message even if errata is embargoed' do
    errata = Errata.find(16409)
    errata.stubs(:is_embargoed? => true)

    (routing_key, message) = message_generated_by { errata.change_state!('NEW_FILES', devel_user) }

    assert_equal 'errata.activity.status', routing_key

    assert_equal({
      'from' => 'QE',
      'to' => 'NEW_FILES',
    }, message.slice('from', 'to'))
  end

  test 'most activity results in embargoed messages for embargoed errata' do
    errata = Errata.find(16409)
    errata.stubs(:is_embargoed? => true)

    (routing_key, message) = message_generated_by do
      ErrataActivity.create!(:errata => errata, :what => 'foo', :removed => 'a',
                             :added => 'b')
    end

    assert_equal 'secalert.errata.activity.foo', routing_key

    assert_equal({
      'from' => 'a',
      'to' => 'b',
    }, message.slice('from', 'to'))
  end

  test 'changing QE owner sends a message' do
    errata = Errata.find(20836)

    (routing_key, message) = message_generated_by do
      errata.assigned_to = User.find_by_login_name!('kernel-qe@redhat.com')
      errata.save!
    end

    assert_equal 'errata.activity.assigned_to', routing_key

    assert_equal({
      'from' => 'qa-errata-list@redhat.com',
      'to' => 'kernel-qe@redhat.com',
    }, message.slice('from', 'to'))
  end

  def message_generated_by(&block)
    jobs = capture_delayed_jobs(/SendMessageJob/) { yield }

    assert_equal 1, jobs.count
    send_message_job = jobs.first

    routing_key = send_message_job.instance_variable_get(:@routing_key)
    message = send_message_job.instance_variable_get(:@message)
    [routing_key, message]
  end
end
