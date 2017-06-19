#!/usr/bin/ruby
require_relative '../qpid_handler'

qpid = QpidHandler.new('qpid.test.engineering.redhat.com')

qpid.topic_subscribe('eso.topic', 'errata.ccat.reschedule_test') do |content, message|
  puts "CCAT test run reschedule - #{content['errata_id']} - #{content.inspect}"
end

qpid.topic_subscribe('eso.topic', 'content-testing.testing-event') do |content, message|
  puts "CCAT send test run - #{content.inspect}"
end

qpid.listen
