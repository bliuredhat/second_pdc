require 'test_helper'

# TODO: replace use of fakeweb with webmock and
# remove VCR.allow_http_connections_when_no_cassette hack
# See: Bug: 1434880
require 'fakeweb'

class JiraIssueTest < ActiveSupport::TestCase
  include FakeJiraRpc
  ISSUES = [
    {
      :key => 'ABC-123',
      :fields => {
        :status => {:name => 'Open',:id => 1},
        :summary => 'summary of ABC-123',
        :updated => '2014-01-07T11:18:33.000+1000',
        :priority => {:id => 3, :name => "Major" },
      },
    },
    {
      :key => 'ABC-456',
      :fields => {
        :status => {:name => 'Open',:id => 1},
        :summary => 'summary of ABC-456',
        :updated => '2014-01-07T11:19:33.000+1000',
        :security => {:id => 10200, :name => 'some security level'},
        :labels => ['Z_label', 'Security', 'Z_label'],
        :priority => {:id => 3, :name => "Major" },
      },
    },
    {
      :key => 'DEF-123',
      :fields => {
        :status => {:name => 'Closed', :id => 2},
        :summary => 'summary of DEF-123',
        :updated => '2014-01-07T12:19:33.000+1000',
        :labels => ['Z_label', 'X_label'],
        :priority => {:id => 2, :name => "Critical" },
      },
    },
    {
      :key => 'DEF-456',
      :fields => {
        :status => {:name => 'Closed', :id => 2},
        :summary => 'summary of DEF-123',
        :updated => '2014-01-07T12:19:33.000+1000',
        :security => {:id => 10201, :name => 'private security level'},
        :priority => {:id => 2, :name => "Critical" },
      },
    },
  ]

  setup do
    Settings.jira_security_level_effects = {
      'private security level' => 'PRIVATE',
    }
    VCR.configure do |c|
      c.allow_http_connections_when_no_cassette = true
    end
  end

  teardown do
    VCR.configure do |c|
      c.allow_http_connections_when_no_cassette = false
    end
  end

  # Returns test JIRA issues.
  # ID and self fields are automatically filled in
  def issues
    id = 10000
    ISSUES.map do |i|
      id += 1
      i.merge(
        :id => id,
        :self => "#{@jira_url}/rest/api/2/issue/#{id}",
        :fields => i[:fields].merge(
          :status => i[:fields][:status].merge(
            :self => "#{@jira_url}/rest/api/2/status/#{i[:fields][:status][:id]}"
          )
        )
      )
    end
  end

  # Convert an issue hash as above to a proper JiraIssue entity
  def self.as_entity(issue)
    JiraIssue.new(
      :key => issue[:key],
      :id_jira => issue[:id],
      :summary => issue[:summary] || "summary of #{issue[:key]}",
      :updated => Time.parse(issue[:fields][:updated]),
      :status => issue[:fields][:status][:name],
      :priority => issue[:fields][:priority][:name],
      :labels => issue[:fields][:labels],
      :jira_security_level => unless (level = issue[:fields][:security]).nil?
        JiraSecurityLevel.new(:id_jira => level[:id], :name => level[:name])
      end
    )
  end

  def assert_entities_equal(expected_hashes, actual_entities)
    expected_entities = expected_hashes.each_with_index.map do |hash,index|
      entity = JiraIssueTest.as_entity(hash)
      entity.id = actual_entities[index].id
      entity
    end
    assert_equal expected_entities, actual_entities
  end

  def register_search(*results)
    options = results.map{|r| {:content_type => 'application/json', :body => r.to_json}}.to_a
    # add a failure in case the search is unexpectedly posted too many times
    options << {:exception => RuntimeError}
    register_uri(:post, '/rest/api/2/search', options)
  end

  test "simple update from RPC" do
    register_search({
      :startAt => 0,
      :maxResults => 100,
      :total => 4,
      :issues => issues,
    })
    updated = JiraIssue.batch_update_from_rpc(%w{ABC-123 ABC-456 DEF-123 DEF-456})
    assert_entities_equal issues, updated

    # security/private should have been set by the labels and security levels on the issues
    sec = updated.find{|x| x.key == 'ABC-456'}
    priv = updated.find{|x| x.key == 'DEF-456'}
    pub = updated.find{|x| x.key == 'ABC-123'}
    assert sec.is_security_restricted?
    assert sec.is_private?

    refute priv.is_security_restricted?
    assert priv.is_private?

    refute pub.is_security_restricted?
    refute pub.is_private?
  end

  test "fatal error on missing issues" do
    register_search({
      :startAt => 0,
      :maxResults => 100,
      :total => 2,
      :issues => issues[0..1]
    })
    error = assert_raises(Jira::JiraIssueNotExist) do
      JiraIssue.batch_update_from_rpc(%w{ABC-123 ABC-456 DEF-123 DEF-456})
    end

    # validateQuery must be set to false, or the real JIRA server will return an error
    # when querying for a nonexistent issue
    params = JSON.parse(FakeWeb.last_request.body)
    assert_equal false, params['validateQuery']
    assert_equal 'key in (ABC-123, ABC-456, DEF-123, DEF-456)', params['jql']

    assert_match /JIRA issue\(s\) don't exist/, error.message
    assert_match /\bDEF-123\b/, error.message
    assert_match /\bDEF-456\b/, error.message
  end

  test "allow missing issues" do
    register_search({
      :startAt => 0,
      :maxResults => 100,
      :total => 2,
      :issues => issues[0..1]
    })

    new_issues = []
    assert_nothing_raised(Jira::JiraIssueNotExist) do
      new_issues = JiraIssue.batch_update_from_rpc(%w{ABC-123 ABC-456 DEF-123 DEF-456}, {:permissive => true})
    end

    # validateQuery must be set to false, or the real JIRA server will return an error
    # when querying for a nonexistent issue
    params = JSON.parse(FakeWeb.last_request.body)
    assert_equal false, params['validateQuery']
    assert_equal 'key in (ABC-123, ABC-456, DEF-123, DEF-456)', params['jql']
    assert_equal issues[0..1].map{|issue| issue[:key]}.sort, new_issues.map(&:key).sort
  end

  test "multiple requests" do
    register_search(
      {
        :startAt => 0,
        :maxResults => 2,
        :total => 4,
        :issues => issues[0..1],
      },
      {
        :startAt => 2,
        :maxResults => 2,
        :total => 4,
        :issues => issues[2..3],
      }
    )
    updated = JiraIssue.batch_update_from_rpc(%w{ABC-123 ABC-456 DEF-123 DEF-456})
    assert_entities_equal issues, updated

    # make sure the client really paginated on the second request
    params = JSON.parse(FakeWeb.last_request.body)
    assert_equal 2, params['startAt']
  end

  test "public private scopes" do
    # sanity check of public vs private
    total_count = JiraIssue.count
    private_issues = JiraIssue.only_private
    public_issues = JiraIssue.only_public
    assert_equal total_count, private_issues.count + public_issues.count, 'total == private + public'
    assert_not_equal 0, private_issues.count, 'have some private issues'
    assert_not_equal 0, public_issues.count, 'have some public issues'
  end

  test "no request with no ids" do
    # FakeWeb will raise an error if this unexpectedly hits the server
    updated = JiraIssue.batch_update_from_rpc([])
    assert_equal [], updated
  end

  test "to_s" do
    str = JiraIssueTest.as_entity(issues[0]).to_s
    assert_equal 'ABC-123 - summary of ABC-123 - Open', str
  end

  test "make_from_rpc creates new issue when key and id have no match" do
    rpc_issue = build_rpc_issue ISSUES[0].deep_merge(
      :id => 12345,
      :key => 'XYZZY-999',
      :fields => {:summary => 'some new issue'}
    )

    issue = nil
    assert_difference('JiraIssue.count', 1) do
      issue = JiraIssue.make_from_rpc rpc_issue
    end

    assert_equal 12345, issue.id_jira
    assert_equal 'XYZZY-999', issue.key
    assert_equal 'some new issue', issue.summary
  end

  test "make_from_rpc updates existing issue when key and id match" do
    saved_issue = JiraIssue.find_by_key!('HSSNAYENG-59')
    rpc_issue = build_rpc_issue ISSUES[0].deep_merge(
      :id => saved_issue.id_jira,
      :key => saved_issue.key,
      :fields => {:summary => 'some updated issue'}
    )

    issue = nil
    assert_no_difference('JiraIssue.count') do
      issue = JiraIssue.make_from_rpc rpc_issue
    end

    assert_equal saved_issue.reload, issue
    assert_equal 'some updated issue', issue.summary
  end

  test "make_from_rpc updates security_level and priority" do
    saved_issue = JiraIssue.find_by_key!('HDS-590')

    rpc_issue = build_rpc_issue ISSUES[0].deep_merge(
      :id => saved_issue.id_jira,
      :key => saved_issue.key,
      :fields => {
        :security => nil,
      }
    )

    issue = nil
    assert_no_difference('JiraIssue.count') do
      issue = JiraIssue.make_from_rpc rpc_issue
    end

    assert_equal nil, issue.security_level
    assert_equal saved_issue.reload, issue

    rpc_issue = build_rpc_issue ISSUES[0].deep_merge(
      :id => saved_issue.id_jira,
      :key => saved_issue.key,
      :fields => {
        :priority => nil,
      }
    )

    assert_no_difference('JiraIssue.count') do
      issue = JiraIssue.make_from_rpc rpc_issue
    end

    assert_equal nil, issue.security_level
    assert_equal nil, issue.priority
    assert_equal saved_issue.reload, issue
  end

  # This case simulates what will happen if an ET which was connected
  # to production JIRA is later connected to a staging JIRA with the
  # same project keys.
  test "make_from_rpc adopts existing issue when only key matches" do
    saved_issue = JiraIssue.find_by_key!('HSSNAYENG-59')
    rpc_issue = build_rpc_issue ISSUES[0].deep_merge(
      :id => 999,
      :key => saved_issue.key,
      :fields => {:summary => 'issue adopted by key'}
    )

    issue = nil
    assert_no_difference('JiraIssue.count') do
      issue = JiraIssue.make_from_rpc rpc_issue
    end

    assert_equal saved_issue.reload, issue
    assert_equal 999, issue.id_jira
    assert_equal 'HSSNAYENG-59', issue.key
    assert_equal 'issue adopted by key', issue.summary
  end

  # This case simulates what will happen if a JIRA issue is moved from
  # one project to another, which causes the key to change.
  test "make_from_rpc adopts existing issue when only ID matches" do
    saved_issue = JiraIssue.find_by_key!('HSSNAYENG-59')
    orig_id = saved_issue.id_jira
    rpc_issue = build_rpc_issue ISSUES[0].deep_merge(
      :id => orig_id,
      :key => 'XYZZY-999',
      :fields => {:summary => 'issue adopted by ID'}
    )

    issue = nil
    assert_no_difference('JiraIssue.count') do
      issue = JiraIssue.make_from_rpc rpc_issue
    end

    assert_equal saved_issue.reload, issue
    assert_equal orig_id, issue.id_jira
    assert_equal 'XYZZY-999', issue.key
    assert_equal 'issue adopted by ID', issue.summary
  end

  # Bug 1199850.  Although the majority of JIRA projects do use a
  # "priority" field, it's possible to disable it, so that needs to
  # work in ET.
  test 'can make_from_rpc with an unset priority' do
    rpc_data = ISSUES[0].merge(
      :id => 9998887,
      :fields => ISSUES[0][:fields].except(:priority))
    rpc_issue = build_rpc_issue rpc_data

    issue = nil
    assert_difference('JiraIssue.count', 1) do
      issue = JiraIssue.make_from_rpc rpc_issue
    end

    assert_equal 'ABC-123', issue.key
    assert_nil issue.priority
  end

  # Bug 1122889
  test 'use non-production links to JIRA issues' do
    with_stubbed_const({:JIRA_URL => 'http://jira.example.com'}, Jira ) do

      # Reset any cached base URL in JiraIssue class variable
      with_stubbed_class_variable({:@@_base_url => nil}, JiraIssue ) do
        Settings.non_prod_bug_links = true
        assert_match /^http:\/\/jira\.example\.com\/browse\//, JiraIssue.first.url
      end

      with_stubbed_class_variable({:@@_base_url => nil}, JiraIssue ) do
        Settings.non_prod_bug_links = false
        assert_match /^https:\/\/issues\.jboss\.org\/browse\//, JiraIssue.first.url
      end
    end
  end

  def build_rpc_issue(hsh)
    Jira::Rpc.get_connection.Issue.build deep_stringify_keys!(hsh.deep_dup)
  end

  # newer ActiveSupport provides this method on hashes already.
  # Ours is too old.
  def deep_stringify_keys!(hsh)
    return unless hsh.respond_to?(:stringify_keys!)
    hsh.stringify_keys!
    hsh.values.each{|x| deep_stringify_keys!(x)}
    hsh
  end
end
