#!/usr/bin/ruby

require 'qpid_handler'

qpid = QpidHandler.new('qpid.engineering.redhat.com')

def print_msg(explanation, msg)
  ts = Time.now.utc.strftime('%Y-%m-%d %H:%M:%S %Z')
  puts "[#{ts}] #{explanation} #{msg.inspect}"
end

qpid.topic_subscribe('eso.topic', 'abidiff.status.started') do |msg|
  print_msg("ABI diff test started", msg)
end

qpid.topic_subscribe('eso.topic', 'abidiff.status.failed') do |msg|
  print_msg("ABI diff test failed", msg)
end

qpid.topic_subscribe('eso.topic', 'abidiff.status.complete') do |msg|
  print_msg("ABI diff test complete", msg)
end

qpid.topic_subscribe('eso.topic', 'covscan.scan.unfinished') do |msg|
  print_msg("Covscan test status updated", msg)
end

qpid.topic_subscribe('eso.topic', 'covscan.scan.finished') do |msg|
  print_msg("Covscan test complete", msg)
end

qpid.listen
