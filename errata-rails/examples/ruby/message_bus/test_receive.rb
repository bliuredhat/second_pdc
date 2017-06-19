#!/usr/bin/ruby
# usage: PN_TRACE_FRM=1 bundle exec ruby test_receive.rb
require_relative 'handler'

mb = MessageBus::Handler.new
begin
  mb.subscribe("queue://Consumer.errata.VirtualTopic.eng.errata.>", nil) do |messages|
    puts messages
  end
rescue StandardError => e
  puts "Subscribe error: #{e.inspect}"
end

mb.listen
