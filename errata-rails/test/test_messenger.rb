require 'qpid_proton'
require 'message_bus/handler'

# This class may be used for testing MessageBus::Handler and friends.
class TestMessenger

  # Create and run a MessageBus::Handler, injecting the given messages into it.
  # This uses real qpid proton messenger instances using AMQP over the loopback
  # interface.
  def self.test_messages(messages)
    self.with_test_receiver do |receiver, port|

      # Currently the sender and receiver for the test must be the same object.
      # The reason is that the main message bus handler event loop is a blocking
      # loop on the receiver only, so the sender won't get a chance to do IO
      # unless it's the same object or we move it to a separate thread or process.
      sender = receiver

      base_addr = "amqp://127.0.0.1:#{port}"

      final_message = TestMessage.new('', MessageBus::Handler::EXIT_SENTINEL)
      self.put_messages(sender, base_addr, messages + [final_message])

      # make the message bus handler subscribe to the right addresses and use
      # our locally bound receiver
      Qpid::Proton::Messenger::Messenger.stubs(:new => receiver)
      MessageBus.send(:remove_const, :BROKER_URL)
      MessageBus.const_set(:BROKER_URL, base_addr)

      h = MessageBus::Handler.new
      h.init_subscriptions
      h.listen
    end
  end

  # Invoke a block with a qpid proton messenger bound to a local
  # port.  The block receives the messenger and the used TCP port
  # as arguments.
  def self.with_test_receiver
    mng, port = new_test_receiver
    begin
      yield(mng, port)
    ensure
      # must be explicitly stopped, or port will remain bound
      mng.stop unless mng.stopped?
    end
  end


  # Make a new messenger bound to a local port.
  def self.new_test_receiver
    (5566..5588).each do |port|
      mng = Qpid::Proton::Messenger::Messenger.new("test-receiver-#{port}")
      begin
        # Including ~ at the beginning of the host part makes it bind.
        # After binding, it'll receive _all_ messages sent to that host
        # and port, regardless of the addresses which have been
        # subscribed to.
        # Other subscriptions must not include the ~ or it'll try to
        # bind multiple times.
        mng.subscribe("amqp://~127.0.0.1:#{port}")
        return mng, port
      rescue Qpid::Proton::ProtonError
        # try next port
      end
    end
    raise "Cannot bind a Qpid::Proton::Messenger::Messenger on any attempted port"
  end

  def self.put_messages(sender, base_addr, messages)
    messages.each do |msg|
      proton_msg = Qpid::Proton::Message.new
      proton_msg.address = [base_addr, msg.address].join('/')
      MBUSLOG.info "TEST: put message to #{proton_msg.address}"
      proton_msg.body = msg.body
      proton_msg.properties = msg.properties || {}
      sender.put(proton_msg)
    end
  end
end

# A class for usage with TestMessenger#test_messages
TestMessage = Struct.new(:address, :body, :properties)
