require 'test_helper'

class JiraRpcTest < ActiveSupport::TestCase
  include FakeJiraRpc

  FIELD_RESOLUTION = {:required => true, :allowedValues => [{:id => 6, :name => 'Done'}]}
  TRANSITION_CLOSE = {
    # transition name is deliberately not 'Close Issue' to prove we're looking at destination status
    :id => 4, :name => 'do something', :to => {:name => 'Closed'},
    :fields => {:resolution => FIELD_RESOLUTION, :assignee => {:required => true}}
  }
  TRANSITION_CLOSE_WITHOUT_FIELDS = TRANSITION_CLOSE.dup.tap{|t| t[:fields] = {}}
  TRANSITION_REOPEN = {
    :id => 5, :name => 'Reopen Issue', :to => {:name => 'Open'}
  }

  setup do
    @_issue = nil

    # TODO: replace use of fakeweb with webmock and
    # remove VCR.allow_http_connections_when_no_cassette hack
    # See: Bug: 1434880
    VCR.configure do |c|
      c.allow_http_connections_when_no_cassette = true
    end
  end

  teardown do
    VCR.configure do |c|
      c.allow_http_connections_when_no_cassette = false
    end
  end

  def issue
    @_issue ||= JiraIssue.new(:key => 'ABC-123', :id_jira => 10010, :summary => 'test issue', :updated => Time.now, :priority => 'Minor')
  end

  def issue_rest_url(issue_id)
    "/rest/api/2/issue/#{issue_id}"
  end

  def transitions_rest_url(issue_id)
    "#{issue_rest_url(issue_id)}/transitions"
  end

  def register_rest(method, url, object)
    options = {:content_type => 'application/json', :body => object.to_json}
    # crash if called more than once
    options = [options, {:exception => RuntimeError}]
    register_uri(method, url, options)
  end

  def register_transitions(issue_id, object)
    register_rest :get, "#{transitions_rest_url(issue_id)}?expand=transitions.fields", object
  end

  def register_assignee(issue_id, object)
    register_rest :get, "#{issue_rest_url(issue_id)}?fields=assignee", object
  end

  def register_add_comment(issue_id, object)
    register_rest :post, "#{issue_rest_url(issue_id)}/comment", object
  end

  test "close succeeds with typical workflow" do
    test_close({:transitions => [TRANSITION_CLOSE,TRANSITION_REOPEN]}) do |closed,postdata,ex|
      assert closed, ex
      assert_equal( {'id' => 4}, postdata['transition'])
      assert_equal( {
        'resolution' => {'name' => 'Done'},
        'assignee' => {'name' => 'test.assignee'},
      }, postdata['fields'])
    end
  end

  test "close succeeds when issue is unassigned" do
    test_close(:transitions => [TRANSITION_CLOSE,TRANSITION_REOPEN], :assignee => nil) do |closed,postdata,ex|
      assert closed, ex
      assert_equal( {'id' => 4}, postdata['transition'])
      assert_equal( {
        'resolution' => {'name' => 'Done'},
        # should post back an assignee with nil name to mean 'unassigned'
        'assignee' => {'name' => nil},
      }, postdata['fields'])
    end
  end

  test "close succeeds when fields are not required" do
    test_close({:transitions => [TRANSITION_CLOSE_WITHOUT_FIELDS]}) do |closed,postdata|
      assert closed
      assert_equal({'id' => 4}, postdata['transition'])
      # no fields, since none were required
      assert_equal({}, postdata['fields'])
    end
  end

  test "close fails when there's no available transition to Closed" do
    test_close({:transitions => [TRANSITION_REOPEN]}) do |closed,postdata,ex|
      refute closed
      assert_kind_of Jira::IllegalTransitionError, ex
      assert_match /No available transition to move to status Closed/, ex.message
      # should not have posted
      assert_nil postdata
    end
  end

  test 'close_or_comment closes when possible' do
    test_close_or_comment({:transitions => [TRANSITION_CLOSE_WITHOUT_FIELDS]}) do |completed,postdata,ex|
      assert_nil ex
      assert completed
      assert_equal({'id' => 4}, postdata['transition'])
      assert_equal Settings.jira_closed_status, issue.status
    end
  end

  test 'close_or_comment adds a comment when closing is not possible' do
    # the posted comment should use this method to get the URL
    fake_url = 'https://example.com/errata123'
    RHBA.any_instance.expects(:errata_public_url).at_least_once.returns(fake_url)
    initial_status = issue.status
    register_add_comment(issue.id_jira, {:unused => :object})
    test_close_or_comment({:transitions => [TRANSITION_REOPEN]}) do |completed,postdata,ex|
      assert_nil ex
      assert completed
      assert_equal ['body'], postdata.keys
      assert_match %r{^This issue has been addressed in}, postdata['body']
      assert_match fake_url, postdata['body']
      assert_equal initial_status, issue.status
    end
  end

  test "close comment uses custom visibility if configured" do
    Settings.jira_close_comment_visibility = Settings.jira_private_comment_visibility
    test_close({:transitions => [TRANSITION_CLOSE,TRANSITION_REOPEN]}) do |closed,postdata,ex|
      assert closed, ex
      assert_equal( Settings.jira_close_comment_visibility, postdata['update']['comment'][0]['add']['visibility'])
    end
  end

  test "can_close returns true with classic workflow" do
    test_can_close({:transitions => [TRANSITION_CLOSE,TRANSITION_REOPEN]}) do |can,postdata,ex|
      assert can
      assert_nil postdata, 'can_close should not POST'
      assert_nil ex, 'can_close should not fail'
    end
  end

  test "can_close returns true when fields are not required" do
    test_can_close({:transitions => [TRANSITION_CLOSE_WITHOUT_FIELDS]}) do |can,postdata,ex|
      assert can
      assert_nil postdata, 'can_close should not POST'
      assert_nil ex, 'can_close should not fail'
    end
  end

  test "can_close returns false when there's no available transition to Closed" do
    test_can_close({:transitions => [TRANSITION_REOPEN]}) do |can,postdata,ex|
      refute can
      assert_nil postdata, 'can_close should not POST'
      assert_nil ex, 'can_close should not fail'
    end
  end

  # can_close works by catching IllegalTransitionError; this test is a protection against
  # the code catching exceptions too broadly
  test "can_close propagates unexpected exceptions" do
    issue = JiraIssue.first
    register_uri(:get, "#{transitions_rest_url(issue.id_jira)}?expand=transitions.fields",
      :response => Net::HTTPInternalServerError.new('HTTP/1.1', 500, 'internal server error'))

    ex = nil
    begin
      Jira::Rpc.get_connection.can_close_issue?(JiraIssue.first)
    rescue StandardError => e
      ex = e
    end

    assert_not_nil ex, 'can_close_issue? should have failed'
    assert_match /\bError response from JIRA: 500 internal server error\b/, ex.message
  end

  test "post comment on security issue" do
    errata = Errata.where(:status => 'SHIPPED_LIVE').first
    issue_id = 10010
    issue = JiraIssue.new(:key => 'DEF-123', :id_jira => issue_id, :summary => 'test issue', :updated => Time.now, :priority => 'Critical')
    Settings.jira_private_comment_visibility = {:type => 'role', :value => 'Developers'}

    jira = Jira::Rpc.get_connection

    # Should refuse to post comment if not a security issue
    refute jira.add_security_resolve_comment(issue, errata)

    issue.labels << 'Security'
    register_uri(:post, "/rest/api/2/issue/#{issue_id}/comment", :body => '')
    assert jira.add_security_resolve_comment(issue, errata)

    r = FakeWeb.last_request
    postdata = JSON.parse(r.body)

    assert_match /\b#{Regexp.escape errata.advisory_name}\b/, postdata['body']
    # should have used the configured visibility
    assert_equal( {'type' => 'role', 'value' => 'Developers'}, postdata['visibility'])
  end

  test "close posts CDN link if advisory uses RHN" do
    e = Errata.find(13147)
    assert e.supports_cdn?
    assert e.supports_rhn_live?

    test_close(:errata => e) do |closed,postdata,ex|
      assert closed, ex
      comment = postdata['update']['comment'][0]['add']['body']
      assert comment.include?('https://access.redhat.com/errata/RHSA-2012:0987'), comment
      refute comment.include?('rhn.redhat.com'), comment
    end
  end

  test "close posts CDN link if advisory was shipped to RHN and config later changed" do
    e = Errata.find(11129)

    # simulate the case that this advisory was shipped to RHN, and RHN
    # support was then disabled for the product
    e.product_versions.each do |pv|
      pv.push_targets = pv.push_targets.select{|pt| pt.name !~ %r{rhn}i}
    end
    e.reload

    # now it supports CDN and not RHN - but it was shipped to RHN
    # previously
    assert e.supports_cdn?
    refute e.supports_rhn_live?
    assert e.has_pushed_rhn_live?

    test_close(:errata => e) do |closed,postdata,ex|
      assert closed, ex
      comment = postdata['update']['comment'][0]['add']['body']
      assert comment.include?('https://access.redhat.com/errata/RHSA-2011:0447'), comment
      refute comment.include?('rhn.redhat.com'), comment
    end
  end

  test "close posts CDN link if advisory does not use RHN" do
    e = Errata.find(16374)
    assert e.supports_cdn?
    refute e.supports_rhn_live?

    test_close(:errata => e) do |closed,postdata,ex|
      assert closed, ex
      comment = postdata['update']['comment'][0]['add']['body']
      assert comment.include?('https://access.redhat.com/errata/RHEA-2014:16374'), comment
      refute comment.include?('rhn.redhat.com'), comment
    end
  end

  def test_close(args, &block)
    test_with_transitions(args, lambda{|jira,issue,errata| jira.close_issue(issue,errata)}, &block)
  end

  def test_close_or_comment(args, &block)
    test_with_transitions(args, lambda{|jira,issue,errata| jira.close_issue_or_comment(issue,errata)}, &block)
  end

  def test_can_close(args, &block)
    test_with_transitions(args, lambda{|jira,issue,errata| jira.can_close_issue?(issue)}, &block)
  end

  def test_with_transitions(args, callback)
    errata = args.delete(:errata) || Errata.where(:status => 'SHIPPED_LIVE').first

    jira = Jira::Rpc.get_connection

    transitions = {:transitions => args.delete(:transitions)||[TRANSITION_CLOSE,TRANSITION_REOPEN]}
    assignee = {:assignee => args.delete(:assignee){{:name => 'test.assignee'}} }
    register_transitions(issue.id_jira, transitions)
    register_assignee(issue.id_jira, :fields => assignee)
    register_uri(:post, transitions_rest_url(issue.id_jira), :body => '')
    ex = nil
    result = false
    begin
      result = callback.call(jira, issue, errata)
    rescue Exception => e
      ex = e
    end

    r = FakeWeb.last_request
    postdata = r.method == 'POST' ? JSON.parse(r.body) : nil
    yield(result, postdata, ex)
  end
end
