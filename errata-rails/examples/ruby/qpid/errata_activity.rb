#!/usr/bin/ruby
require 'qpid_handler'

qpid = QpidHandler.new(ENV['QPID_HOST'] || 'qpid.engineering.redhat.com')

qpid.topic_subscribe 'eso.topic', 'errata.created' do |content, message|
  puts "#{content['type']} advisory created - #{content.inspect}"
end

qpid.topic_subscribe 'eso.topic', 'errata.bugs.added' do |content|
  puts "Bug #{content['bug_id']} added to advisory #{content['errata_id']} - #{content.inspect}"
end

qpid.topic_subscribe 'eso.topic', 'errata.bugs.dropped' do |content|
  puts "Bug #{content['bug_id']} removed from advisory #{content['errata_id']} - #{content.inspect}"
end

qpid.topic_subscribe 'eso.topic', 'errata.builds.added' do |content|
  puts "Build #{content['brew_build']} added to advisory #{content['errata_id']} - #{content.inspect}"
end

qpid.topic_subscribe 'eso.topic', 'errata.builds.removed' do |content|
  puts "Build #{content['brew_build']} removed from advisory #{content['errata_id']} - #{content.inspect}"
end

qpid.topic_subscribe 'eso.topic', 'errata.activity.#' do |content, message|
  print "Advisory #{content['errata_id']} "
  case message.getSubject
  when 'errata.activity.status'
    print "state changed from #{content['from']} #{content['to']}"
  when 'errata.activity.release'
    print "release changed from #{content['from']} #{content['to']}"
  else
    print "'#{message.getSubject.sub(/^errata.activity./,'')}' by #{content['who']}"
  end
  puts " - #{content.inspect}"
end

qpid.listen
