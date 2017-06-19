#!/usr/bin/ruby
require_relative '../qpid_handler'

qpid = QpidHandler.new('qpid.test.engineering.redhat.com')

properties =
{
  "qpid.subject" => "content-testing.testing-event",
  "x-amqp-0-10.routing-key" => "content-testing.testing-event",
  "ERRATA_ID" => "25297",
  "TARGET" => "cdn-live",
  "MESSAGE_TYPE" => "pass"
}

content =
{
  "MESSAGE" => "job pass",
  "BUILD_URL" => "https://content-test-jenkins.rhev-ci-vms.eng.rdu2.redhat.com/job/cdn_content_validation/19112/"
}

qpid.topic_send('eso.topic', 'content-testing.testing-event', content, properties)

puts "CCAT send test run - pass"
