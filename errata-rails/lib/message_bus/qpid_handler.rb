# Uses cqpid api, which at present is in the ruby-qpid-qmf package
#
# cqpid SWIG around c++ api:
# http://qpid.apache.org/apis/0.14/cpp/html/a00596.html
#
# http://docs.redhat.com/docs/en-US/Red_Hat_Enterprise_MRG/2/html/Programming_in_Apache_Qpid/index.html
#
require 'cqpid'

module MessageBus
  class QpidHandler
    #-------------------------------------------------------------------------
    # Each module included registers a subscription method
    # which then gets called in do_subscriptions below.
    # (Maybe there is a better way to do this).
    #
    def self.add_subscriptions(subscribe_method)
      (@@all_subscribe_methods ||= []) << subscribe_method
    end

    include Abidiff
    include Covscan
    include Ccat

    #-------------------------------------------------------------------------

    def initialize(host=Qpid::HOST, port=Qpid::PORT)
      @connection = Cqpid::Connection.new(server_url(host, port))
      @connection.setOption("sasl_mechanisms", "GSSAPI")

      # So we don't hang forever if the qpid server stops responding
      @connection.setOption("heartbeat", 10)

      if 5671 == port
        # Need to have the server cert or IT CA cert installed since the C++ api
        # enforces ssl validation.
        #
        # sudo yum -y install nss-tools
        # wget --no-check-certificate http://password.corp.redhat.com/cacert.crt
        # sudo certutil -d /etc/pki/nssdb/ -A -i /tmp/cacert.crt -n redhat -t C
        # export QPID_SSL_CERT_DB=/etc/pki/nssdb
        # Ignored in 0.14, fixed again upstream.
        # See https://bugzilla.redhat.com/show_bug.cgi?id=817283#c1
        @connection.setOption("transport", "ssl")
      end

      say "Opening connection to #{host}:#{port}"
      @connection.open()

      say "Creating session"
      @session = @connection.createSession()
      @callbacks = {}

      @default_callback = lambda do |content, message|
        output content, message
      end
    end

    def topic_send(exchange, routing_key, content, properties = {})
      sender = @session.createSender(exchange)
      msg = encode_msg content
      msg.setSubject(routing_key)
      properties.each do |key, value|
        msg.setProperty(key, value)
      end
      sender.send msg
    end

    def output(content, message)
      say "Headers are:"
      say message.getProperties().inspect
      reply_to = message.getReplyTo()
      unless reply_to.nil? || reply_to.str().empty?
        say "Reply to: #{reply_to.str()}"
      end

      say "Subject: #{message.getSubject()}"
      say "Sent by User: #{message.getUserId()}"
      say "Message content:"
      say content.inspect
      say "\n\n"
    end

    def close
      @session.close()
      @connection.close()
    end

    def topic_subscribe(exchange, routing_key, &block)
      unless block.nil? || [1,2].include?(block.arity)
        raise "Handler must take either |content| or |content, qpid_message|"
      end

      queue_name = ['tmp', ENV['USER'], routing_key, "#{Time.now.to_i}"].join('.')
      opts =
        {'create' => 'receiver',
        'node' =>
        {'type' => 'queue',
          'durable' => 'False',
          'x-declare' => {'exclusive' => 'True', 'auto-delete' => 'True', 'arguments' => {'qpid.policy_type' => 'ring'}},
          'x-bindings' => [ {'exchange' => exchange, 'key' => routing_key} ]
        }
      }
      address = Cqpid::Address.new(queue_name, '', opts, '')
      say "Binding to address: #{address.str()}"
      recv = @session.createReceiver(address)
      recv.setCapacity(10)
      @callbacks[queue_name] = block unless block.nil?
    end

    def init_subscriptions
      # The subscribe_methods come from the included modules, currently Abidiff and Covscan
      @@all_subscribe_methods.each { |subscribe_method| self.send(subscribe_method) }
    end

    def listen
      ['TERM', 'INT'].each do |signal|
        trap(signal) do
          Thread.new { say "Exiting" }
          close()
          $exit = true
        end
      end
      say 'starting to listen'
      loop do
        begin
          return if $exit
          # Neccessary to use timeout since ruby does not yet
          # use nonblocking IO. Othewise, sigint/term/etc won't
          # be caught.
          rec = @session.nextReceiver(Cqpid::Duration.SECOND)
          fetch_message(rec)
        rescue MessagingError => e
          raise e if e.message !~ /No message to fetch/
        ensure
          ActiveRecord::Base.verify_active_connections!
        end
      end
    end

    private

    def encode_msg(msg)
      if msg.is_a?(Hash) || msg.is_a?(Array)
        message = Cqpid::Message.new
        Cqpid.encode(msg, message)
      else
        message = Cqpid::Message.new msg
      end
      message
    end

    # https://bugzilla.redhat.com/show_bug.cgi?id=817283#c1
    def server_url(host, port)
      return "#{host}:#{port}" unless 5671 == port
      "amqp:ssl:#{host}:#{port}"
    end

    def fetch_message(rec)
      message = rec.fetch
      content = parse_msg(message)
      @session.acknowledge()

      handler = @callbacks[rec.getName()]
      handler ||= @default_callback

      if handler.arity == 1
        handler.call(content)
      else
        handler.call(content, message)
      end
    end

    def parse_msg(message)
      content_type = message.getContentType()
      case content_type
      when 'amqp/map'
        return Cqpid.decodeMap message
      when "amqp/list"
        return Cqpid.decodeList message
      else
        return message.getContent()
      end
    end

    def say(msg)
      MBUSLOG.info msg
      puts msg
    end


  end
end
