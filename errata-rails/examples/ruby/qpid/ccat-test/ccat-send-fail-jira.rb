#!/usr/bin/ruby
require_relative '../qpid_handler'

qpid = QpidHandler.new('qpid.test.engineering.redhat.com')

properties =
{
  "qpid.subject" => "content-testing.testing-event",
  "x-amqp-0-10.routing-key" => "content-testing.testing-event",
  "ERRATA_ID" => "25609",
  "TARGET" => "cdn-live",
  "JIRA_ISSUE_ID" => "RCM-9877",
  "JIRA_ISSUE_URL" => "https://projects.engineering.redhat.com/browse/RCM-9877",
  "MESSAGE_TYPE" => "fail",
  #"JOB_NAME"=>"cdn_content_validation_manual",
  "ERROR_CAUSE" => '["Problems:","testing ERROR_CAUSE"]'
}

content =
{
  "MESSAGE" => "job fail",
  "BUILD_URL" => "https://content-test-jenkins.rhev-ci-vms.eng.rdu2.redhat.com/job/cdn_content_validation/19116/"
}

qpid.topic_send('eso.topic', 'content-testing.testing-event', content, properties)

puts "CCAT send test run - fail with jira issue added"
