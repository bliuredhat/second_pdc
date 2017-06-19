#
# DelayedJob for putting messages on the message bus
#
# SendMsgJob will replace SendMessageJob in future,
# and during the transition period, will keep
# SendMessageJob working for a while.
#
module MessageBus

  REDACTED = "REDACTED".freeze

  class SendMsgJob

    attr_reader :topic, :message, :properties

    def initialize(topic, message, properties={})
      @topic = topic
      @message = message
      @properties = properties
    end

    def perform
      mb = MessageBus::Handler.new
      mb.topic_send(topic, message, properties)
    end

    def to_s
      "SendMsg:\ntopic: #{topic}\nheaders: #{properties.inspect}\nbody: #{message.inspect}"
    end

  end

  def self.enqueue(topic, message, properties, embargoed: false, material_info_select: nil)

    return unless Settings.messages_to_umb_enabled

    if embargoed
      material_info_select ||= topic
      material_info = get_material_info_keys(material_info_select)

      redact message, material_info if material_info
      redact properties, material_info if material_info
    end

    Delayed::Job.enqueue SendMsgJob.new(topic, message, properties), 5
    MBUSLOG.info "Queued for UMB: #{topic} #{properties.inspect} #{message.inspect}"
  end

  # Redact the 'material information' of message or properties
  def self.redact(message_or_properties, keys)
    MBUSLOG.info "Redacted: #{message_or_properties} #{keys}"
    (message_or_properties.keys & keys).each do |key|
      message_or_properties[key] = MessageBus::REDACTED
    end
  end

  def self.get_material_info_keys(material_info_select)
    Settings.message_material_keys[material_info_select]
  end
end