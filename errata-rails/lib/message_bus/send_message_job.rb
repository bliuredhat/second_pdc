#
# DelayedJob for putting messages on the bus
#
module MessageBus
  class SendMessageJob

    def initialize(message, routing_key)
      @message = message
      @routing_key = routing_key
    end

    def perform
      mb = MessageBus::QpidHandler.new
      begin
        mb.topic_send(Qpid::EXCHANGE, @routing_key, @message)
      ensure
        mb.close
      end
    end

    def to_s
      "SendMessage #{@message.inspect} to key #{@routing_key}"
    end

    def self.enqueue(message, routing_key_suffix, embargoed = false)

      return unless Settings.messages_to_qpid_enabled

      prefix = Qpid::SECURE_TOPIC_PREFIX if embargoed
      prefix ||= Qpid::TOPIC_PREFIX

      routing_key = "#{prefix}.#{routing_key_suffix}"

      Delayed::Job.enqueue SendMessageJob.new(message, routing_key), 5
      MBUSLOG.info "Queued: #{Qpid::HOST} #{Qpid::PORT} #{Qpid::EXCHANGE} #{routing_key} #{message.inspect}"
    end

  end

  def self.send_message(message, routing_key_suffix, embargoed = false)
    SendMessageJob.enqueue(message, routing_key_suffix, embargoed)
  end
end
