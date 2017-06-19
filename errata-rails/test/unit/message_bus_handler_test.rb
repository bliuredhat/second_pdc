require 'test_helper'
require 'test_messenger'

class MessageBusHandlerTest < ActiveSupport::TestCase
  test 'initially selects working broker from list' do
    port = nil

    logs = TestMessenger.with_test_receiver do |receiver, p|
      port = p
      set_broker_url [500, port, 501].map { |x| "amqp://127.0.0.1:#{x}" }
      put_stop_message(receiver, "amqp://127.0.0.1:#{port}")
      Qpid::Proton::Messenger::Messenger.expects(:new).once.returns(receiver)

      run_handler
    end

    [
      'INFO Listening for messages from broker amqp://127.0.0.1:500',
      %r{^WARN amqp://127\.0\.0\.1:500 failed connection test:.+},
      'INFO Trying next broker momentarily...',
      "INFO Listening for messages from broker amqp://127.0.0.1:#{port}",
      'INFO Exiting without error.'
    ].each { |match| log_match_upto!(logs, match) }
  end

  test 'switches to next broker if current broker fails' do
    port1 = nil
    port2 = nil

    logs = TestMessenger.with_test_receiver do |recv1, p1|
      port1 = p1

      TestMessenger.with_test_receiver do |recv2, p2|
        port2 = p2
        set_broker_url [port1, port2].map { |x| "amqp://127.0.0.1:#{x}" }

        [
          [recv1, port1],
          [recv2, port2]
        ].each_with_index do |(recv, port), idx|
          msg = Qpid::Proton::Message.new
          msg.address = "amqp://127.0.0.1:#{port}"
          msg.body = "test message #{idx + 1}"

          recv.put(msg)
        end

        put_stop_message(recv2, "amqp://127.0.0.1:#{port2}")

        Qpid::Proton::Messenger::Messenger.stubs(:new).returns(recv1, recv2)

        fake_receive = crashing_receive(recv1, 1)
        self.class.with_replaced_method(recv1, :receive, fake_receive) { run_handler }
      end
    end

    [
      # receives a message from first broker...
      "INFO Listening for messages from broker amqp://127.0.0.1:#{port1}",
      /^DEBUG Received:.*"test message 1"/,

      # then an error occurred, switched to the next broker...
      %r{^ERROR Error receiving from amqp://127\.0\.0\.1:#{port1}:.+},
      'INFO Trying next broker momentarily...',

      # received a message from second broker...
      "INFO Listening for messages from broker amqp://127.0.0.1:#{port2}",
      /^DEBUG Received:.*"test message 2"/,

      # then finished
      'INFO Exiting without error.'
    ].each { |match| log_match_upto!(logs, match) }
  end

  test 'gives up if all brokers are unusable' do
    set_broker_url [500, 501, 502].map { |x| "amqp://127.0.0.1:#{x}" }

    error = nil
    run_proc = lambda do |h|
      begin
        h.listen
      rescue StandardError => error
      end
    end

    logs = run_handler(run_proc)

    # it would be good to test the raised error here,
    # but proton tends to give fairly useless exceptions such as:
    # ArgumentError: Unknown error code: -5

    # it should retry each broker a few times.  We don't test exactly how many
    # but make sure it cycles at least once.
    2.times do
      [500, 501, 502].each do |port|
        [
          "INFO Listening for messages from broker amqp://127.0.0.1:#{port}",
          %r{^WARN amqp://127\.0\.0\.1:#{port} failed connection test:.+}
        ].each { |match| log_match_upto!(logs, match) }
      end
    end

    log_match_upto!(logs, 'ERROR Giving up due to repeated failures from every configured broker.')
  end

  test "doesn't give up if messages have been received recently" do
    Settings.mbus_last_receive = 1.minute.ago

    logs = TestMessenger.with_test_receiver do |receiver, port|
      set_broker_url [500, 501, port].map { |x| "amqp://127.0.0.1:#{x}" }

      # simulate a failed connection many many times, then eventually succeed
      MessageBus::Handler.any_instance.expects(:test_connection!).at_least_once.tap do |e|
        92.times { e = e.then.raises('Simulated error') }
        e = e.then.returns(nil)
      end

      put_stop_message(receiver, "amqp://127.0.0.1:#{port}")

      Qpid::Proton::Messenger::Messenger.stubs(:new).returns(receiver)

      run_handler
    end

    log_match_upto!(logs, 'INFO Exiting without error.')
  end

  test 'test_connection closes and does not propagate error' do
    socket = mock

    TCPSocket.expects(:new).with('host.example.com', 1234).once.returns(socket)
    socket.expects(:close).once.raises('Error on close!')

    h = MessageBus::Handler.new
    h.send(:test_connection!, 'amqps://host.example.com:1234/quux')
  end

  test 'routes based on properties' do
    address = nil
    logs = TestMessenger.with_test_receiver do |receiver,port|
      address = "amqp://127.0.0.1:#{port}"
      set_broker_url [address]

      # add some custom subscriptions during this test
      run_proc = lambda do |h|
        h.subscribe("foo", {"h1" => "v1", "h2" => "v2"}) do |msgs|
          assert_equal 1, msgs.length
          msg = msgs.first
          Rails.logger.info "GOT: #{msg.id}"
        end
        h.subscribe("bar", {"does_not" => "match"}) do |msgs|
          flunk "unexpectedly matched message #{msgs.inspect}"
        end
        h.subscribe("baz", {"h1" => "v1"}) do |msgs|
          flunk "unexpectedly matched message #{msgs.inspect}"
        end
        h.listen
      end

      bad_msg1 = Qpid::Proton::Message.new
      bad_msg1.id = 'ID:bad_msg1'
      bad_msg1.address = "#{address}/foo"
      bad_msg1.body = "test bad message"
      bad_msg1.properties = {"does_not" => "match"}

      # this message matches properties, but against the wrong address
      bad_msg2 = Qpid::Proton::Message.new
      bad_msg2.id = 'ID:bad_msg2'
      bad_msg2.address = "#{address}/bar"
      bad_msg2.body = "test bad message"
      bad_msg2.properties = {"h1" => "v1", "h2" => "v2", "h3" => "v3"}

      good_msg = Qpid::Proton::Message.new
      good_msg.id = 'ID:good_msg'
      good_msg.address = "#{address}/foo"
      good_msg.body = "test good message"
      good_msg.properties = {"h1" => "v1", "h2" => "v2", "h3" => "v3"}

      [bad_msg1, bad_msg2, good_msg].each do |msg|
        receiver.put(msg)
      end

      put_stop_message(receiver, address)

      Qpid::Proton::Messenger::Messenger.expects(:new).once.returns(receiver)

      run_handler(run_proc)
    end

    [
      "INFO Listening for messages from broker #{address}",
      /^WARN Received a message which did not match any subscribers:\s+ID:\s+ID:bad_msg1/,
      /^WARN Received a message which did not match any subscribers:\s+ID:\s+ID:bad_msg2/,
      'INFO GOT: ID:good_msg',
      'INFO Exiting without error.',
    ].each{|match| log_match_upto!(logs, match)}
  end

  # run a MessageBus::Handler and return captured logs
  def run_handler(run_proc = nil)
    h = MessageBus::Handler.new
    h.init_subscriptions

    h.stubs(:sleep)

    run_proc ||= lambda { |handler| handler.listen }

    capture_logs { run_proc.call(h) }
  end

  # Assert that a log message exists matching the given string or pattern.
  # Consumes from logs up to the matching log, which tests the log ordering.
  def log_match_upto!(logs, match)
    notmatch = []
    until logs.empty?
      log = logs.shift
      log = [log[:severity], log[:msg]].join(' ')
      if match.is_a?(Regexp) && log =~ match
        assert true
        return
      elsif match.is_a?(String) && match == log
        assert true
        return
      else
        notmatch << log
      end
    end
    flunk "Expected log matching #{match}, got:\n  #{notmatch.join("\n  ")}"
  end

  def put_stop_message(mng, address)
    msg = Qpid::Proton::Message.new
    msg.address = address
    msg.body = MessageBus::Handler::EXIT_SENTINEL
    mng.put(msg)
  end

  # On a messenger, return a receive method which crashes on the i'th invocation,
  # and otherwise receives successfully.
  # Can't use mocha because it has no way to pass through to the normal
  # implementation.
  def crashing_receive(mng, i)
    real_receive = mng.method(:receive)
    count = 0
    lambda do |*args|
      if count < i
        count += 1
        return real_receive.call(*args)
      end
      raise "Simulated error!"
    end
  end

  def set_broker_url(url)
    MessageBus.send(:remove_const, :BROKER_URL)
    MessageBus.const_set(:BROKER_URL, url)
  end
end
