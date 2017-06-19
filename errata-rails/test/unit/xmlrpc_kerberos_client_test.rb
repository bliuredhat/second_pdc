require 'test_helper'

class TestClientA < XMLRPC::KerberosClient
  def initialize(opts)
    super('https://example.com/xmlrpc', opts)
  end
end

class TestClientB < XMLRPC::KerberosClient
  def initialize(opts)
    super('https://example.com/xmlrpc', opts)
  end
end

class TestClientC < TestClientB
end

class XMLRPC::KerberosClientTest < ActiveSupport::TestCase

  # Bug 1125786
  test 'each subclass maintains its own singleton instance' do
    a = TestClientA.instance
    b = TestClientB.instance
    c = TestClientC.instance

    assert a.object_id != b.object_id
    assert a.object_id != c.object_id
    assert b.object_id != c.object_id
  end

  test 'instance returns a singleton' do
    [TestClientA,TestClientB,TestClientC].each do |klass|
      x = klass.instance
      y = klass.instance

      assert_equal x.object_id, y.object_id
    end
  end

  test 'instance returns an object of the correct class' do
    a = TestClientA.instance
    b = TestClientB.instance
    c = TestClientC.instance

    assert_equal TestClientA, a.class
    assert_equal TestClientB, b.class
    assert_equal TestClientC, c.class
  end

  # Bug 1132771
  test 'ResponseNotOkay message is a string when XML-RPC fault occurs' do
    client = XMLRPC::KerberosClient.new('http://example.com/xmlrpc')
    curl = ::Curl::Easy.any_instance
    curl.expects(:http_post).returns('x')
    curl.expects(:body_str).returns(<<'eos')
<?xml version="1.0"?>
<methodResponse>
   <fault>
      <value>
         <struct>
            <member>
               <name>faultCode</name>
               <value><int>88</int></value>
            </member>
            <member>
               <name>faultString</name>
               <value><string>simulated fault</string></value>
            </member>
         </struct>
      </value>
   </fault>
</methodResponse>
eos

    ex = assert_raises(XMLRPC::KerberosClient::ResponseNotOkay) {
      client.someMethod()
    }

    assert_equal '88: simulated fault', ex.message
  end
end
