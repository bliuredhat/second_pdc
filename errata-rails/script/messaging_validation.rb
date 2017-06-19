#!/usr/bin/ruby
# usage: PN_TRACE_FRM=1 bundle exec rails runner messaging_validation.rb
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
require 'socket'
require 'zabbix/zabbix_sender'

ENV['QPID_SSL_CERT_DB'] ||= '/etc/pki/nssdb'
ENV['QPID_SSL_CERT_NAME'] ||= MessageBus::CERT_NAME

# Need to put quotes around the topic/consuming_address urls, cause the qpid
# messaging API assumes addresses in the form <node-name>/<subject>, so
# without quoting it takes the portion up to the first '/' as the node name,
# and everything thereafter as the subject.
TOPICS = %w(
  "topic://VirtualTopic.eng.errata.>"
).freeze

CONSUMING_ADDRS = %w(
  "queue://errata_from_esb"
).freeze

puts "Messaging validation on env: #{Rails.env}"

def validate

  errors = []
  # validate if there is an available broker
  begin
    broker_url = URI.parse(broker)
  rescue StandardError => e
    puts "Get umb broker error: #{e.inspect}"
    return errors << {:error => e.inspect}
  end

  broker  = "amqp:#{broker_url.host}:#{broker_url.port}"
  puts "validating umb #{broker}"
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

def broker
  broker_urls = Array.wrap(MessageBus::BROKER_URL)
  broker_urls.each do |broker_url|
    begin
      test_connection!(broker_url)
      return broker_url
    rescue StandardError => e
      puts "#{broker_url} failed connection test: #{e.inspect}"
    end
  end
  raise 'No available broker.'
end

def test_connection!(url)
  u = URI.parse(url)
  socket = nil
  begin
    puts "Testing connection to #{u.host}:#{u.port}..."
    socket = TCPSocket.new(u.host, u.port)
    puts "Connected OK."
  ensure
    unless socket.nil?
      begin
        puts "Closing socket after connection test..."
        socket.close
        puts "Closed socket OK."
      rescue StandardError => e
        log_error "Error closing socket after connection test on #{url}", e
      end
    end
  end
end

def validate_topics(session, errors)
  puts "\nvalidating topics:"
  TOPICS.each do |topic|
    puts "#{topic}"
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
  puts "\nvalidating consuming addresses:"
  CONSUMING_ADDRS.each do |consuming_addr|
    puts "#{consuming_addr}"
    address = Qpid::Messaging::Address.new("#{consuming_addr}; {create:never, mode:browse}")
    begin
      session.create_receiver address
    rescue StandardError => e
      errors << {:address => consuming_addr, :type => "queue", :error => e.inspect}
      puts "[UMB] Create receiver error: #{e.inspect}"
    end
  end
end

if $0 == __FILE__
  errors = validate
  zabbix_sender = Zabbix::ZabbixSender.new
  if errors.any?
    puts "validation failed.\n#{errors.inspect}"
    zabbix_sender.send(Zabbix::KEY_UMB_CONNECTION, errors.inspect)
  elsif
    zabbix_sender.send(Zabbix::KEY_UMB_CONNECTION, "OK")
    puts "validation successfully."
  end
end