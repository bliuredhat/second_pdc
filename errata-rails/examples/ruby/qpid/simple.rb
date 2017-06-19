#!/usr/bin/ruby
require 'qpid_handler'

qpid = QpidHandler.new('qpid.engineering.redhat.com')

qpid.topic_subscribe('eso.topic', 'errata.#') do |content, message|
  puts \
    '-'*28,
    Time.now.utc,
    "Headers: #{message.getProperties.inspect}",
    "Subject: #{message.getSubject.inspect}",
    "Content: #{content.inspect}"
end

qpid.listen
