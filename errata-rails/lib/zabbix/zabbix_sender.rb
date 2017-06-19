require "socket"
require "base64"

#
# Zabbix sender protocol implementation in Ruby
# Ref: https://www.zabbix.org/wiki/Docs/protocols/zabbix_sender/1.1/ruby_example
#
module Zabbix
  class ZabbixSender
    def initialize(host = Zabbix::HOST, port = Zabbix::PORT)
      @socket = TCPSocket.new(host,port)
    end

    # zbx_host:
    #   The custom hostname configured in Zabbix for the networked
    #   entity (physical, virtual).
    #   https://www.zabbix.com/documentation/3.0/manual/quickstart/host
    # zbx_key:
    #   A key is a name of an item that identifies the type of information
    #   that will be gathered.
    #   https://www.zabbix.com/documentation/3.0/manual/quickstart/item
    def send(zbx_host = Zabbix::ERRATA_HOSTNAME, zbx_key, data)

      ZABBIX_LOG.info "Sending to zabbix server:\n#{zbx_host} | #{zbx_key} | #{data}"

      request = %{
        <req>
          <host>#{Base64.encode64(zbx_host)}</host>
          <key>#{Base64.encode64(zbx_key)}</key>
          <data>#{Base64.encode64(data)}</data>
        </req>
      }.strip_heredoc.strip

      begin
        @socket.puts request
        result = @socket.gets
        ZABBIX_LOG.info "Zabbix server replied: #{result}"
        return result.chomp
      rescue => e
        ZABBIX_LOG.error e.inspect
      ensure
        @socket.close
      end
    end
  end
end