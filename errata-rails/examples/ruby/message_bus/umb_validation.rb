#!/usr/bin/ruby
# usage: PN_TRACE_FRM=1 bundle exec ruby umb_validation.rb
#
# Installing the Certificate
# ==========================
#
# You need to have the IT CA cert installed since the C++ api
# enforces SSL validation. This can be done as follows:
#
#  sudo yum -y install nss-tools
#  wget --no-check-certificate https://password.corp.redhat.com/RH-IT-Root-CA.crt
#  sudo certutil -d /etc/pki/nssdb/ -A -i ./RH-IT-Root-CA.crt -n RH-IT-Root -t CT,c,c
#  sudo pk12util -i /tmp/msg-client-errata-dev.p12 -d /etc/pki/nssdb
#  export QPID_SSL_CERT_DB=/etc/pki/nssdb
#  export QPID_SSL_CERT_NAME=<cert name>
#  check cert name: sudo certutil -d /etc/pki/nssdb/ -L

require 'qpid_messaging'
require 'uri'
require_relative 'handler'

ENV['QPID_SSL_CERT_DB'] ||= '/etc/pki/nssdb'
ENV['QPID_SSL_CERT_NAME'] ||= MessageBus::CERT_NAME

TOPICS = %w(
  "topic:://VirtualTopic.eng.errata.>"
).freeze

CONSUMING_ADDRS = %w(
  "queue://errata_from_esb"
).freeze

def validate

  errors = []
  mb = MessageBus::Handler.new

  # validate if there is an available broker
  begin
    broker_url = URI.parse(mb.broker)
  rescue StandardError => e
    puts "Get umb broker error: #{e.inspect}"
    return errors << {:error => e.inspect}
  end

  broker  = "amqp:#{broker_url.host}:#{broker_url.port}"
  puts "validate on umb #{broker}"
  connection = Qpid::Messaging::Connection.new(:url => broker, :options => {transport:'ssl'})
  begin
    connection.open
  rescue StandardError => e
    puts "UMB connection error: #{e.inspect}"
    connection.close
    return errors << {:broker => broker, :error => e.inspect}
  end

  session = connection.create_session
  # validate if ET has the write permission on the topics
  validate_topics(session, errors)
  # validate if ET has the read permission on the consuming addresses
  validate_consuming_addrs(session, errors)

  session.close
  connection.close
  errors
end

def validate_topics(session, errors)
  TOPICS.each do |topic|
    puts "\n#{topic}"
    address = Qpid::Messaging::Address.new("#{topic}; {create:never, node:{type:topic}}")
    begin
      session.create_sender address
    rescue StandardError => e
      errors << {:address => topic, :type => "topic", :error => e.inspect}
      puts "[UMB] Create sender error: #{e.inspect}"
    end
  end
end

def validate_consuming_addrs(session, errors)
  CONSUMING_ADDRS.each do |consuming_addr|
    puts "\n#{consuming_addr}"
    address = Qpid::Messaging::Address.new("#{consuming_addr}; {create:never, mode:browse}")
    begin
      session.create_receiver address
    rescue StandardError => e
      errors << {:address => consuming_addr, :type => "queue", :error => e.inspect}
      puts "[UMB] Create receiver error: #{e.inspect}"
    end
  end
end

errors = validate
puts errors.inspect if errors.any?