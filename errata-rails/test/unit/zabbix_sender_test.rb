require 'test_helper'

class ZabbixTest < ActiveSupport::TestCase

  ZABBIX_SERVER = "127.0.0.1"
  ZABBIX_KEY = "errata.umb.conn".freeze
  DATA = "{:error => unauthorized_access}".freeze

  setup do
    server = TCPServer.new(ZABBIX_SERVER, 10051)
    handle_request(server)
  end

  test 'test zabbix sender' do
    zabbix_sender = Zabbix::ZabbixSender.new(ZABBIX_SERVER, 10051)
    assert_equal "OK", zabbix_sender.send(ZABBIX_KEY,DATA)
  end

  def handle_request(server)
    expect_req = %{
      <req>
        <host>#{Base64.encode64(Zabbix::ERRATA_HOSTNAME)}</host>
        <key>#{Base64.encode64(ZABBIX_KEY)}</key>
        <data>#{Base64.encode64(DATA)}</data>
      </req>
    }.strip_heredoc.strip

    Thread.new do
      while session = server.accept
        lines = ""
        while line = session.gets do
          lines << line.chomp
          session.puts "OK" if lines.gsub(/\s+/, "") == expect_req.gsub(/\s+/, "")
        end
        server.close
      end
   end
  end
end