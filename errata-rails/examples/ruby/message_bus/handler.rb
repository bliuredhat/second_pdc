require 'qpid_proton'
require 'uri'
require 'socket'
require_relative 'umb_configuration'

module MessageBus
  class Handler
    # max number of messages we'll pull from the broker in a single operation
    MAX_MESSAGES = 100

    # Trick to enable testing.
    # In the usual case, the handler runs an infinite loop.
    # For testing, if you send this message to the handler, it'll exit from
    # the loop.
    # The body is random, the idea being that only the current process should
    # be able to send this.
    EXIT_SENTINEL = "MessageBus::Handler exit #{sprintf '%04x', rand(2**16)}".freeze

    # Add a static subscription for the given address.
    # If props are provided, only subscribe to messages matching exactly the given
    # properties.
    # This subscription will be enacted on every MessageBus::Handler instance created
    # after the call to this method.
    def self.subscribe(address, props = nil, &block)
      static_subs[address] ||= []
      static_subs[address] << [props, block]
    end

    def self.subscribed_addresses
      static_subs.keys
    end

    def initialize(url=MessageBus::BROKER_URL)
      @broker_urls = Array.wrap(url)

      @cert = MessageBus::CLIENT_CERT
      @key = MessageBus::CLIENT_KEY

      unless @cert.nil?
        puts ("Using cert #{@cert} & key #{@key} for message bus authentication")
      end

      @subs = {}
    end

    def topic_send(topic, content, properties={})
      messenger = new_messenger(broker)

      msg = build_message(topic)
      msg.properties = properties
      msg.body = content

      begin
        puts "Sending message to: #{msg.address}"
        puts "Message header: #{msg.properties}"
        puts "Message body: #{msg.body}"

        # The outgoing window acts like a threshold, in that tracking information
        # is only available for "window_size" sent message. So the outgoing_window
        # need to be set a higher number than the default 0.
        messenger.outgoing_window = 1
        messenger.put msg
        messenger.send

        outgoing_tracker = messenger.outgoing_tracker
        if messenger.status(outgoing_tracker) != Qpid::Proton::Messenger::TrackerStatus::ACCEPTED
          raise "Send message to #{msg.address} failed."
        end
        puts "Send message to #{msg.address} successfully."
      ensure
        messenger.settle(outgoing_tracker)
        messenger.stop
      end
    end

    def broker
      @broker_urls.each do |broker_url|
        begin
          test_connection!(broker_url)
          return broker_url
        rescue StandardError => e
          puts "#{broker_url} failed connection test: #{e.inspect}"
        end
      end
      raise 'No available broker.'
    end

    def build_message(topic)
      msg = Qpid::Proton::Message.new
      msg.subject = topic
      msg.durable = true
      msg.address = "topic://VirtualTopic.eng.#{topic}"
      msg["hostname"] = ErrataSystem::SERVICE_NAME
      return msg
    end

    def init_subscriptions
      MessageBus::Handler.static_subs.each do |address, props_and_blocks|
        props_and_blocks.each do |props, block|
          subscribe(address, props, &block)
        end
      end
    end

    def subscribe(address, props, &block)
      unless @subs.include? address
        puts "Will subscribe to #{address}"
      end
      @subs[address] ||= []
      @subs[address] << [props, block]
    end

    # Enter an event loop receiving and processing messages.
    def listen
      attempt = 0
      max = @broker_urls.length * 5
      @broker_urls.cycle.each do |url|
        attempt += 1

        error = listen_with_broker(url)

        if error.nil?
          # should happen in autotests only
          puts "Exiting without error."
          return
        end

        # never give up if we've managed to connect successfully some
        # time in the last few minutes
        #before = Settings.mbus_last_receive
        #if before && before > 5.minutes.ago
        #  attempt = 0
        #end

        if attempt > max
          # all brokers are repeatedly not working.  Time to give up.
          puts "Giving up due to repeated failures from every configured broker."
          raise error
        end

        #MBUSLOG.info "Trying next broker momentarily..."
        sleep 5
      end
    end

    # Start the main listening loop with a particular broker.
    # This is supposed to run as an infinite loop.
    # If an error occurs receiving messages from the broker, the error is
    # returned so that the caller can try the next broker if appropriate.
    # Other errors are propagated.
    def listen_with_broker(url)
      puts "Listening for messages from broker #{url}"

      begin
        test_connection!(url)
      rescue StandardError => e
        puts "#{url} failed connection test: #{e.inspect}"
        return e
      end

      messenger = new_messenger(url)

      while true
        should_exit = dispatch_all(url, messenger)
        if should_exit
          nonblock_stop(messenger)
          return
        end

        begin
          messenger.work(0)
          messenger.receive(MAX_MESSAGES)
        rescue Qpid::Proton::TimeoutError
          # no messages arrived, not a problem
        rescue StandardError => e
          log_error "Error receiving from #{url}", e
          nonblock_stop(messenger)
          return e
        end

        #update_last_receive

        # stale connections can be left over from handlers
        #ActiveRecord::Base.verify_active_connections!
      end
    end

    private

    def self.static_subs
      @static_subs ||= {}
    end

    def self.messenger_name
      #"errata-#{Rails.env}-#{(0..5).map{rand(16).to_s(16)}.join}"
    end

    def test_connection!(url)
      u = URI.parse(url)
      socket = nil
      begin
        puts "Testing connection to #{u.host}:#{u.port}..."
        socket = TCPSocket.new(u.host, u.port)
        puts "Connected OK."
      ensure
        unless socket.nil?
          begin
            puts "Closing socket after connection test..."
            socket.close
            puts "Closed socket OK."
          rescue StandardError => e
            log_error "Error closing socket after connection test on #{url}", e
          end
        end
      end
    end

    def nonblock_stop(messenger)
      messenger.blocking = false
      begin
        messenger.stop
      rescue StandardError => e
        log_error "Could not stop messenger", e
      end
    end

    def log_error(prefix, e)
      puts "#{prefix}: #{e.inspect}\n#{e.backtrace.map{|line| "  #{line}"}.join("\n")}"
    end

    def new_messenger(url)
      messenger = Qpid::Proton::Messenger::Messenger.new(self.class.messenger_name)

      # Our connection is to a single broker only, resolve all addresses
      # relative to that broker.
      messenger.route('*', "#{url}/$1")

      unless @cert.nil?
        messenger.certificate = @cert
        messenger.private_key = @key
      end

      @subs.keys.each{|address| messenger.subscribe(address)}

      # We'll block for a message for up to this long; it needs to be fairly short
      # so we can service heartbeats from the broker
      messenger.timeout = 5000

      # Very important to set this. If omitted, defaults to 0, meaning all
      # messages are auto-settled using a default outcome selected by the
      # server, which is most likely going to be "release", resulting in
      # messages being redelivered later.
      # See https://issues.apache.org/jira/browse/PROTON-484
      messenger.incoming_window = MAX_MESSAGES

      messenger.start()

      messenger
    end

    def dispatch_all(broker_url, messenger)
      message = Qpid::Proton::Message.new

      while messenger.incoming > 0
        tracker = messenger.get(message)
        puts "Received: #{message}"
        dispatch(broker_url, message)

        if message.body == EXIT_SENTINEL
          return true
        end

        messenger.accept(tracker)
        messenger.settle(tracker)
      end

      nil
    end

    def dispatch(broker_url, message)
      matched = false

      @subs.each do |address, props_and_blocks|
        next unless match_address?(broker_url, address, message.address)

        props_and_blocks.each do |props, block|
          next unless match_props?(props, message)
          matched = true

          begin
            block.call([message])
          rescue StandardError => e
            # errors in handlers don't go any further than this; the listener should survive
            log_error "Error handling messages to #{address}", e
          end
        end
      end

      warn_unmatched(message) unless matched
    end

    def warn_unmatched(message)
      puts [
        'Received a message which did not match any subscribers:',
        "  ID:      #{message.id}",
        "  Address: #{message.address.inspect}",
        "  Props:   #{message.properties.inspect}",
      ].join("\n")
    end

    def match_address?(broker_url, sub_addr, message_addr)
      # message address may have broker URL prepended (e.g. when testing on localhost)
      message_addr.gsub!( %r{^#{Regexp.escape(broker_url)}/}, '')

      return true if sub_addr == message_addr

      # ActiveMQ VirtualTopic case.
      # Subscribing to:
      #
      #   queue://Consumer.X.VirtualTopic.bar
      #
      # ... will get you messages delivered to:
      #
      #   topic://VirtualTopic.bar
      if sub_addr =~ %r{^queue://Consumer\..*?\.(VirtualTopic\..+)$}
        return true if message_addr == "topic://#{$1}"
      end

      false
    end

    def match_props?(props, message)
      props ||= {}
      props.all? do |key, val|
        message[key] == val
      end
    end

    # Update the setting tracking the last mbus receive to now.
    # Internally throttles updates to avoid too many DB writes
    def update_last_receive
      now = Time.now
      @wrote_last_receive ||= Settings.mbus_last_receive
      if @wrote_last_receive.blank? || now - @wrote_last_receive > 5.minutes
        @wrote_last_receive = Settings.mbus_last_receive = now
      end
    end
  end
end
