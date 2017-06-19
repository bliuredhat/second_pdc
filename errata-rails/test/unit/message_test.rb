require 'test_helper'
require 'message_bus/send_msg_job'

class MessageTest < ActiveSupport::TestCase

  test 'redact material information' do
    material_info = %w(who errata_status from to)

    message = {
      'subject'      => 'errata.activity.status',
      'who'          => 'errata_test@redhat.com',
      'when'         => Time.now,
      'errata_id'    => 9788,
      'errata_status'=> State::REL_PREP,
      'from'         => State::QE,
      'to'           => State::REL_PREP
    }

    MessageBus.redact(message, material_info)
    material_info.each do |key|
      assert_equal message[key], MessageBus::REDACTED
    end
  end

  test 'sending msg result in the delayed job' do
    topic = 'errata.test'
    message = {
      info: 'test sending msg'
    }

    properties = {
      subject: topic,
      info: 'test sending msg'
    }

    jobs = capture_delayed_jobs(/SendMsgJob/) do
      MessageBus.enqueue(topic, message, properties)
    end

    assert_equal 1, jobs.count
    send_msg_job = jobs.first

    assert_equal topic, send_msg_job.topic
    assert_equal message, send_msg_job.message
    assert_equal properties, send_msg_job.properties
  end

end
