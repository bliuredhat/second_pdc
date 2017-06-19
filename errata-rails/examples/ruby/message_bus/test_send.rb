#!/usr/bin/ruby
# usage: PN_TRACE_FRM=1 bundle exec ruby test_send.rb
require_relative 'handler'

# Set message header
message_properties = {
  errata_id: "9677",
  who: "errata_test@redhat.com",
  when: Time.now.to_s
}

# Set message body
message_body = {
  errata_id: "9677",
  who: "errata_test@redhat.com",
  when: Time.now.to_s
}

mb = MessageBus::Handler.new
begin
  mb.topic_send("errata.test", message_body, message_properties)
rescue StandardError => e
  puts "Topic send error: #{e.inspect}"
end
