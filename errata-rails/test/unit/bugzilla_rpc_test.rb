#
# See lib/bugzilla/rpc.rb
#
require 'test_helper'

class BugzillaRpcAuthProxyTest < ActiveSupport::TestCase

  setup do
    @server = Bugzilla::Rpc::BugzillaConnection.new('ignored_host')
    @auth_proxy = @server.auth_proxy('Dummy')
    @rpc = mock('XMLRPC::Client::Proxy')
    @auth_proxy.instance_variable_set(:@proxy, @rpc)
    @dummy_token = 'qwerty123'
  end

  def token_expect(use_token)
    @server.expects(:call)\
      .with('User.login', all_of(has_key('login'), has_key('password')))\
      .returns(use_token ? {'token' => @dummy_token} : {})
  end

  test "adds token when needed for method with no args" do
    token_expect(true)
    @rpc.expects(:bananas).once.with({'Bugzilla_token' => @dummy_token})
    @auth_proxy.bananas()
  end

  test "adds token when needed for method with args" do
    token_expect(true)
    @rpc.expects(:bananas).once.with({:foo => 'bar', 'Bugzilla_token' => @dummy_token})
    @auth_proxy.bananas(:foo => 'bar')
  end

  test "do not add token if not applicable for method with no args" do
    token_expect(false)
    @rpc.expects(:bananas).once.with()
    @auth_proxy.bananas()
  end

  test "do not add token if not applicable for method with args" do
    token_expect(false)
    @rpc.expects(:bananas).once.with({:foo => 'bar'})
    @auth_proxy.bananas(:foo => 'bar')
  end

end

class BugzillaRpcTest < ActiveSupport::TestCase
  setup do
    @text_only_rhsa = Errata.find(11149)
    assert @text_only_rhsa.text_only?
    assert @text_only_rhsa.is_security?
    @security_bug = Bug.find(1139115)
    @bz = Bugzilla::Rpc.new
    @proxy = @bz.instance_variable_get('@bug')
  end

  test "close posts CDN link if advisory uses RHN" do
    e = Errata.find(13147)
    assert e.supports_cdn?
    assert e.supports_rhn_live?

    test_close(:errata => e) do |update|
      comment = update[:comment][:body]
      assert comment.include?('https://access.redhat.com/errata/RHSA-2012:0987'), comment
      refute comment.include?('rhn.redhat.com'), comment
    end
  end

  test "close posts CDN link if advisory does not use RHN" do
    e = Errata.find(16374)
    assert e.supports_cdn?
    refute e.supports_rhn_live?

    test_close(:errata => e) do |update|
      comment = update[:comment][:body]
      assert comment.include?('https://access.redhat.com/errata/RHEA-2014:16374'), comment
      refute comment.include?('rhn.redhat.com'), comment
    end
  end

  test 'security resolve comment uses errata public URL' do
    e = Errata.find(11149)
    bug = Bug.find(1139115)
    bz = Bugzilla::Rpc.new
    proxy = bz.instance_variable_get('@bug')

    fake_url = 'https://example.com/some-errata'
    e.expects(:errata_public_url).returns(fake_url)
    proxy.expects(:add_comment).with(
      has_entries(:id => bug.id, :comment => includes(fake_url)))

    bz.add_security_resolve_comment(bug, e)
  end

  test 'security resolve comment uses the list of product versions' do
    rhsa = Errata.find(11110)
    refute rhsa.text_only?
    assert rhsa.is_security?
    @proxy.expects(:add_comment).with(
      has_entries(:id => @security_bug.id,
                  :comment => includes("JBEAP 5 for RHEL 4","JBEAP 5 for RHEL 5")))

    @bz.add_security_resolve_comment(@security_bug, rhsa)
  end

  test 'text-only RHSA resolve comment uses product.name when has no dists, no product_version_text' do
    assert_blank @text_only_rhsa.content.product_version_text
    assert_blank @text_only_rhsa.text_only_channel_list.get_all_channel_and_cdn_repos

    assert_product_version_text(@text_only_rhsa.product.name)
  end

  test 'text-only RHSA resolve comment uses product versions from dists when has dists only' do
    assert_blank @text_only_rhsa.content.product_version_text
    @text_only_rhsa.stubs(:text_only_channel_list).returns(TextOnlyChannelList.new)
    cdn_repos = CdnRepo.where(:name => ['redhat-rhscl-perl-520-rhel7',
                                        'rhs-3-for-rhel-6-server-rpms__6Server__x86_64'])
    TextOnlyChannelList.any_instance.stubs(:get_all_channel_and_cdn_repos).
      returns(cdn_repos)

    assert_product_version_text("Red Hat Enterprise Linux 7\n  Red Hat Storage 3 for RHEL 6")
  end

  test 'text-only RHSA resolve comment uses product_version_text when has product_version_text only' do
    product_version_text = 'JBoss Application Server (for text only advisories)'
    @text_only_rhsa.content.stubs(:product_version_text).returns(product_version_text)
    assert_blank @text_only_rhsa.text_only_channel_list.get_all_channel_and_cdn_repos

    assert_product_version_text(product_version_text)
  end

  test 'text-only RHSA resolve comment uses product_version_text when has both dists and text' do
    product_version_text = 'JBoss Application Server (for text only advisories)'
    @text_only_rhsa.content.stubs(:product_version_text).returns(product_version_text)
    @text_only_rhsa.stubs(:text_only_channel_list).returns(TextOnlyChannelList.new)
    TextOnlyChannelList.any_instance.stubs(:get_all_channel_and_cdn_repos).
      returns(CdnRepo.last(2))

    assert_product_version_text(product_version_text)
  end

  test 'text-only RHSA resolve comment splits product_version_text by comma' do
    @text_only_rhsa.content.stubs(:product_version_text).returns('Text A, Text B')

    assert_product_version_text("Text A\n  Text B")
  end

  def assert_product_version_text(expected_text)
    comment = "This issue has been addressed in the following products:\n\n  #{expected_text}\n\nVia"
    @proxy.expects(:add_comment).with(
      has_entries(:id => @security_bug.id, :comment => includes(comment)))

    @bz.add_security_resolve_comment(@security_bug, @text_only_rhsa)
  end

  def test_close(args)
    rpc = Bugzilla::Rpc.new

    rpc_bug = rpc.instance_variable_get('@bug')
    update = nil
    rpc_bug.expects(:update).once.with{|args|
      update = args
      true
    }

    bug = Bug.find(697046)
    assert bug.can_close?

    rpc.closeBug(bug, args[:errata])

    yield update
  end
end
