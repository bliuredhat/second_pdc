#
# Usage
# =====
#
# Please see the examples in this directory to see how to use this to connect and
# subscribe to topics.
#
# Note that you need a valid kerberos ticket and the SSL certificate installed as
# described below.
#
#
# Installing Dependencies
# =======================
#
# This uses the cqpid api, which at present is in the 'ruby-qpid-qmf' package.
# You also need to install 'qpid-cpp-client-ssl'.
#
#     sudo yum install -y ruby-qpid-qmf qpid-cpp-client-ssl
#
# These are the versions I am using currently:
#
#   qpid-cpp-client.x86_64            0.14-22.el6_3         @Updates
#   qpid-cpp-client-ssl.x86_64        0.14-22.el6_3         @Updates
#   qpid-qmf.x86_64                   0.14-14.el6_3         @Updates
#   ruby-qpid-qmf.x86_64              0.14-14.el6_3         @Updates
#
#
# Installing the Certificate
# ==========================
#
# You need to have the server cert or IT CA cert installed since the C++ api
# enforces SSL validation. This can be done as follows:
#
#     sudo yum -y install nss-tools
#     wget --no-check-certificate http://password.corp.redhat.com/cacert.crt
#     sudo certutil -d /etc/pki/nssdb/ -A -i ./cacert.crt -n redhat -t C
#     export QPID_SSL_CERT_DB=/etc/pki/nssdb
#
#
# Further Information
# ===================
#
# Howtos and other docs:
# https://docs.engineering.redhat.com/display/HTD/Errata+Tool+Qpid+Howtos
#
# The cqpid SWIG around C++ API:
# http://qpid.apache.org/apis/0.14/cpp/html/a00596.html
#
# See also:
# http://docs.redhat.com/docs/en-US/Red_Hat_Enterprise_MRG/2/html/Programming_in_Apache_Qpid/
#
#

# Let's set the default cert location here if the env var isn't set already
ENV['QPID_SSL_CERT_DB'] ||= '/etc/pki/nssdb'

require 'cqpid'

#
# Base class for listening to qpid messages
#
class QpidHandler
  def initialize(host, port=5671)
    url = server_url(host, port)
    @connection = Cqpid::Connection.new(url)
    @connection.setOption("sasl_mechanisms", "GSSAPI")
    if 5671 == port
      # (ssl transport ignored in 0.14, fixed again upstream,
      # see https://bugzilla.redhat.com/show_bug.cgi?id=817283#c1 )
      @connection.setOption("transport", "ssl")
    end

    say "Opening connection #{url}"
    @connection.open()

    say "Creating session"
    @session = @connection.createSession()

    @callbacks = {}
    @default_callback = lambda do |content, message|
      output(content, message)
    end
  end

  def output(content, message)
    say "Headers are:"
    say message.getProperties().inspect
    reply_to = message.getReplyTo()
    unless reply_to.nil? || reply_to.str().empty?
      say "Reply to: #{reply_to.str()}"
    end

    say "Subject: #{message.getSubject()}"
    say "Sent by User: #{message.getUserId()}"
    say "Message content:"
    say content.inspect
    say "\n\n"
  end

  def close
    @session.close()
    @connection.close()
  end

  def topic_subscribe(exchange, routing_key, &block)
    unless block.nil? || [1,2].include?(block.arity)
      raise "Handler must take either |content| or |content, qpid_message|"
    end

    queue_name = ['tmp', ENV['USER'], routing_key, "#{Time.now.to_i}"].join('.')
    opts = {
      'create' => 'receiver',
      'node' => {
        'type' => 'queue',
        'durable' => 'False',
        'x-declare' => {'exclusive' => 'True', 'auto-delete' => 'True', 'arguments' => {'qpid.policy_type' => 'ring'}},
        'x-bindings' => [ {'exchange' => exchange, 'key' => routing_key} ],
      }
    }
    address = Cqpid::Address.new(queue_name, '', opts, '')
    say "Binding to address: #{address.str()}"
    recv = @session.createReceiver(address)
    recv.setCapacity(10)
    @callbacks[queue_name] = block unless block.nil?
  end

  def listen
    ['TERM', 'INT'].each do |signal|
      trap(signal) do
        Thread.new { say "Exiting" }
        close()
        $exit = true
      end
    end
    say 'staring to listen'
    loop do
      begin
        return if $exit
        # Neccessary to use timeout since ruby does not yet
        # use nonblocking IO. Othewise, sigint/term/etc won't
        # be caught.
        rec = @session.nextReceiver(Cqpid::Duration.SECOND)
        fetch_message(rec)
      rescue MessagingError => e
        raise e if e.message !~ /No message to fetch/
      end
    end
  end

  def topic_send(exchange, routing_key, content, properties = {})
    sender = @session.createSender(exchange)
    msg = encode_msg(content)
    msg.setSubject(routing_key)
    properties.each do |key, value|
      msg.setProperty(key, value)
    end
    sender.send(msg)
  end

  def encode_msg(msg)
    if msg.is_a?(Hash) || msg.is_a?(Array)
      message = Cqpid::Message.new
      Cqpid.encode(msg, message)
    else
      message = Cqpid::Message.new(msg)
    end
    message
  end

  private

  # Work around https://bugzilla.redhat.com/show_bug.cgi?id=817283#c1
  def server_url(host, port)
    return "#{host}:#{port}" unless 5671 == port
    "amqp:ssl:#{host}:#{port}"
  end

  def fetch_message(rec)
    message = rec.fetch
    content = parse_msg(message)
    @session.acknowledge()

    handler = @callbacks[rec.getName()]
    handler ||= @default_callback

    if handler.arity == 1
      handler.call(content)
    else
      handler.call(content, message)
    end
  end

  def parse_msg(message)
    case message.getContentType()
    when 'amqp/map'
      Cqpid.decodeMap(message)
    when 'amqp/list'
      Cqpid.decodeList(message)
    else
      message.getContent()
    end
  end

  def say(msg)
    puts msg
  end
end
