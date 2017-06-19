require 'test_helper'
approot = File.expand_path(File.join(File.dirname(__FILE__), '../..'))
require File.join(approot, 'script', 'messaging_validation')

class MessagingValidationTest < ActiveSupport::TestCase
  test 'report error when there is no available broker' do
    stubs(:test_connection!).raises(StandardError, 'Connection error.')
    errors = validate
    assert errors.first[:error].include?("No available broker.")
  end

  test 'report error when errors happens on topics' do
    topic_error = 'amqp:unauthorized-access: User is not authorized to write to: topic://topic1'
    stubs(:broker).returns("amqps://127.0.0.1:5671")
    conn = mock
    Qpid::Messaging::Connection.stubs(:new).returns(conn)
    conn.expects(:open)

    session = mock
    conn.expects(:create_session).returns(session)
    session.expects(:create_sender).raises(StandardError, topic_error)
    session.expects(:close)
    conn.expects(:close)
    stubs(:validate_consuming_addrs)

    errors = validate
    assert errors.first[:error].include?(topic_error)
  end

  test 'report error when errors happens on queue' do
    queue_error = "amqp:unauthorized-access: User is not authorized to read from: queue://queue1"
    stubs(:broker).returns("amqps://127.0.0.1:5671")
    conn = mock
    Qpid::Messaging::Connection.stubs(:new).returns(conn)
    conn.expects(:open)

    session = mock
    conn.expects(:create_session).returns(session)
    session.expects(:create_receiver).raises(StandardError, queue_error)
    session.expects(:close)
    conn.expects(:close)
    stubs(:validate_topics)

    errors = validate
    assert errors.first[:error].include?(queue_error)
  end
end