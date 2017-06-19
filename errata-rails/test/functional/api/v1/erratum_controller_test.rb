require 'test_helper'

module TestCaseHelpers

  def json_response(*args)
    response = ActiveSupport::JSON.decode @response.body
    _traverse_response(response, args)
  end

  def _traverse_response(response, keys)
    value = response.fetch(keys.shift, response)
    return value if keys.empty?
    _traverse_response(value, keys)
  end

end

class Api::V1::ErratumControllerTest < ActionController::TestCase

  include TestCaseHelpers

  setup do
    auth_as admin_user

    type = 'RHBA'
    @text = "No libbeer in the fridge"
    @user = User.first
    @release = Async.find(21)
    @release.update_attributes(:enabled => 1, :isactive => 1)
    @release.update_attribute('product_versions',
                              Release.find_by_name('RHEL-6.1.0').product_versions)
    @product = @release.product_versions.first.product
    bugs = Bug.unfiled.with_states("MODIFIED").take(2)
    bugs.map do
      |b| b.update_attribute('flags', @release.blocker_flags.join('+, ') + '+')
    end
    @idsfixed = bugs.map(&:id).join(' ')
    jira_issues = JiraIssue.unfiled.take(2)
    @jira_issues_fixed = jira_issues.map(&:key)
    @all_issues = []
    @all_issues.concat(bugs.map(&:id))
    @all_issues.concat(@jira_issues_fixed)

    login_name = @user.login_name

    @params = {
      :product             => @product.short_name,
      :release             => @release.name,
      :advisory            => {
        :solution            => @text,
        :description         => @text,
        :text_only           => false,
        :keywords            => "environment-modules",
        :manager_email       => login_name,
        :package_owner_email => login_name,
        :synopsis            => @text,
        :reboot_suggested    => "false",
        :topic               => @text,
        :idsfixed            => @all_issues.join(' '),
        :security_impact     => "Low",
        :errata_type         => type,
      }
    }

    @rhsa = @release.errata.new_files.
      where(:errata_type => 'RHSA').
      where('release_date IS NULL OR release_date <= ?', Time.now).
      first
    @rhea = RHEA.find(11112) # in state QE
  end

  test "create advisory errors are captured" do
    post :create,
      :format   => :json,
      :advisory => {:errata_type => "RHBA"}
    assert_response :unprocessable_entity
    assert_match    %r{be blank}, json_response.values.uniq.flatten.join(' ')

    post :create,
      :format   => :json,
      :advisory => {:text_only => 0}
    assert_response :unprocessable_entity

    post :create,
      :format   => :json,
      :product => 'RHEL'
    assert_response :unprocessable_entity

    post :change_state,
      :format    => :json,
      :id        => rhba_async.id,
      :new_state => State::QE
    assert_response :unprocessable_entity
    assert_match %r{complete RPMDiff}, json_response('errors', 'base').join

    post :create,
      :format => :json,
      :id => @rhea.id,
      :advisory => {
        :idsfixed => Bug.active.last.id.to_s,
      }
    assert_response :unprocessable_entity
    assert_match %r{non-security Bugs}, json_response('errors', 'idsfixed').flatten.join(' ')
  end

  test "can't find product" do
    post :create, @params.merge(:product => 'FRHEL')
    assert_response :error
    assert_match %r{find Product without an ID}, response.body
  end

  test "can't find release" do
    post :create, @params.merge(:release => 'FASYNC')
    assert_response :error
    assert_match %r{find Release without an ID}, response.body
  end

  test "create RHEA" do
    assert_create_type_of_advisory RHEA.name
  end

  test "create RHBA" do
    assert_create_type_of_advisory RHBA.name
  end

  test "create RHSA" do
    auth_as secalert_user
    assert_create_type_of_advisory RHSA.name
    assert Errata.last.is_security?
  end

  test "can create RHBA with approved docs" do
    @params.deep_merge!(:advisory => {:doc_complete => 1})
    e = assert_create_type_of_advisory RHBA.name
    assert e.docs_approved?
  end

  test "clone advisory with custom fields" do
    assert_clone_advisory @release.errata.new_files.first
  end

  test "clone RHSA as security user" do
    auth_as secalert_user

    assert_clone_advisory @rhsa, 'rhsa'
  end

  test "clone RHSA as non-security user" do
    assert_clone_advisory @rhsa
  end

  test "clone RHSA as non-security user specifying parameters" do
    # even specifying explicitly the errata type will not turn it into
    # an RHSA
    params = {
      :format => :json,
      :id => @rhsa.id,
      :advisory => {:idsfixed => @all_issues.join(' '), :errata_type => 'RHSA',
        :synopsis  => @text }
    }
    assert_clone_advisory @rhsa, 'rhba', params
  end

  test "clone a shipped advisory as devel" do
    auth_as devel_user

    e = RHBA.find(11031)
    assert e.shipped_live?
    assert e.closed?
    assert e.docs_approved?

    cloned = assert_clone_advisory(e, 'rhba', {
        :format => :json,
        :id => e.id,
        :advisory => {
          # value not important, just have to set at least one valid bug
          :idsfixed => e.release.bugs.where(:bug_status => %w[MODIFIED VERIFIED])\
            .first.id.to_s,
          :synopsis => @text,
        }
      })

    # none of these should be set on a cloned advisory, regardless
    # of the source advisory
    refute cloned.shipped_live?
    refute cloned.closed?
    refute cloned.docs_approved?
    refute cloned.docs_approval_requested?
  end

  test "cloned advisory does not copy QE assignee" do
    e = RHBA.find(11031)
    assert_not_equal User.default_qa_user, e.assigned_to

    cloned = assert_clone_advisory(e, 'rhba', {
        :format => :json,
        :id => e.id,
        :advisory => {
          # value not important, just have to set at least one valid bug
          :idsfixed => e.release.bugs.where(:bug_status => %w[MODIFIED VERIFIED])\
            .first.id.to_s,
          :synopsis => @text,
        }
      })

    # Cloned advisory should have default QE assignee
    assert_equal User.default_qa_user, cloned.assigned_to
  end

  # Bug 920907
  test 'rhsa synopsis impact removed when cloning to rhba' do
    auth_as secalert_user
    rhsa = Errata.find(11149)
    assert_equal 'Moderate: JBoss Enterprise Web Server 1.0.2 update', rhsa.synopsis

    assert_difference('RHBA.count') do
      post :clone, :format => :json, :id => rhsa.id,
           :advisory => {:idsfixed => '697835',
                         :errata_type => 'RHBA'}
      assert_response :success, response.body
    end

    cloned = RHBA.last

    # Cloned advisory should not have copied "Moderate: " synopsis prefix
    assert_equal 'JBoss Enterprise Web Server 1.0.2 update', cloned.synopsis
  end

  test "update advisory" do
    put :update,
      :format => :json,
      :id => @rhea.id,
      :advisory => {
        'package_owner_email' => User.last.login_name,
      }
    assert_response :success

    get :show,
      :format => :json,
      :id => @rhea.id
    assert_equal User.last.id, json_response('errata', 'rhea', 'package_owner_id')
  end

  test "non-secalert user can change to RHSA with low impact" do
    auth_as devel_user

    put :update,
      :format => :json,
      :id => rhba_async.id,
      :advisory => {
      :errata_type => RHSA.name,
      :security_impact => 'Low',
      :idsfixed => @idsfixed
      }
    assert_response :success
  end

  test "non-secalert user cannot change to RHSA with non-low impact" do
    auth_as devel_user

    put :update,
      :format => :json,
      :id => rhba_async.id,
      :advisory => {
      :errata_type => RHSA.name,
      :security_impact => 'Moderate',
      :idsfixed => @idsfixed
      }
    assert_response :unprocessable_entity
  end

  test "non-secalert user cannot change to RHSA with embargo date" do
    auth_as devel_user

    put :update,
      :format => :json,
      :id => rhba_async.id,
      :advisory => {
      :errata_type => RHSA.name,
      :security_impact => 'Low',
      :embargo_date => '2024-11-10',
      :idsfixed => @idsfixed
      }
    assert_response :unprocessable_entity
  end

  test "request docs approval" do
    advisory = Errata.new_files.first
    refute advisory.docs_approval_requested?

    put :update,
      :format => :json,
      :id => advisory.id,
      :advisory => {
        'text_ready' => '1'
      }
    assert_response :success, response.body
    advisory.reload
    assert advisory.docs_approval_requested?
  end

  test "approve docs when approval was requested" do
    advisory = Errata.new_files.first
    advisory.request_docs_approval!
    refute advisory.docs_approved?

    put :update,
      :format => :json,
      :id => advisory.id,
      :advisory => {
        'doc_complete' => '1'
      }
    assert_response :success
    advisory.reload
    assert advisory.docs_approved?
    refute advisory.docs_approval_requested?

    # ensure appropriate observers were run
    advisory.activities.most_recent.first.tap{|a|
      assert_equal 'docs_approved', a.what
      assert_equal admin_user, a.who
    }
  end

  test "approve docs when approval was not requested" do
    advisory = Errata.new_files.first
    refute advisory.docs_approval_requested?

    put :update,
      :format => :json,
      :id => advisory.id,
      :advisory => {
        'doc_complete' => '1'
      }
    assert_response :success
    advisory.reload
    assert advisory.docs_approved?
    refute advisory.docs_approval_requested?

    advisory.activities.most_recent.first.tap{|a|
      assert_equal 'docs_approved', a.what
      assert_equal admin_user, a.who
    }
  end

  test "cannot approve docs if missing role" do
    advisory = Errata.new_files.first
    advisory.request_docs_approval!

    auth_as devel_user

    put :update,
      :format => :json,
      :id => advisory.id,
      :advisory => {
        'doc_complete' => '1'
      }
    assert_response :unprocessable_entity

    advisory.reload
    refute advisory.docs_approved?
    assert advisory.docs_approval_requested?
  end

  test "can disapprove docs" do
    advisory = Errata.find(11123)
    assert advisory.docs_approved?
    auth_as admin_user

    put :update,
      :format => :json,
      :id => advisory.id,
      :advisory => {
        'doc_complete' => '0'
      }
    assert_response :success, response.body

    advisory.reload
    refute advisory.docs_approved?
    refute advisory.docs_approval_requested?

    advisory.activities.most_recent.first.tap{|a|
      assert_equal 'docs_rejected', a.what
      assert_equal admin_user, a.who
    }
  end

  test "cannot disapprove docs if missing role" do
    advisory = Errata.find(11123)
    assert advisory.docs_approved?
    auth_as devel_user

    put :update,
      :format => :json,
      :id => advisory.id,
      :advisory => {
        'doc_complete' => '0'
      }
    assert_response :unprocessable_entity

    advisory.reload
    assert advisory.docs_approved?
    refute advisory.docs_approval_requested?
  end

  test "re-request docs approval implicitly disapproves" do
    advisory = Errata.find(11123)
    assert advisory.docs_approved?
    refute advisory.docs_approval_requested?
    auth_as admin_user

    put :update,
      :format => :json,
      :id => advisory.id,
      :advisory => {
        'text_ready' => '1',
      }
    assert_response :success, response.body

    advisory.reload
    assert advisory.docs_approval_requested?
    refute advisory.docs_approved?

    advisory.activities.most_recent.first.tap{|a|
      assert_equal 'docs_approval_requested', a.what
      assert_equal admin_user, a.who
    }
  end

  test "cannot change text_ready and doc_complete together" do
    advisory = Errata.find(11123)
    assert advisory.docs_approved?
    refute advisory.docs_approval_requested?
    auth_as admin_user

    put :update,
      :format => :json,
      :id => advisory.id,
      :advisory => {
        'text_ready' => '1',
        'doc_complete' => '0',
      }
    assert_response :unprocessable_entity
  end

  test 'can request security approval' do
    e = rel_prep_unrequested_rhsa
    put :update,
      :format => :json,
      :id => e.id,
      :advisory => {:security_approved => false}
    assert_response :success, response.body
    assert e.reload.security_approval_requested?
  end

  test 'can approve security' do
    e = rel_prep_requested_rhsa
    auth_as secalert_user
    put :update,
      :format => :json,
      :id => e.id,
      :advisory => {:security_approved => true}
    assert_response :success, response.body
    assert e.reload.security_approved?
  end

  test 'can disapprove security' do
    e = rel_prep_approved_rhsa
    put :update,
      :format => :json,
      :id => e.id,
      :advisory => {:security_approved => nil}
    assert_response :success, response.body
    refute e.reload.security_approved?
    refute e.security_approval_requested?
  end

  test 'cannot request security approval of wrong advisory type' do
    e = rel_prep_rhba
    put :update,
      :format => :json,
      :id => e.id,
      :advisory => {:security_approved => false}
    assert_response :unprocessable_entity, response.body
    assert_equal ['is not used for this advisory'], json_response('errors', 'security_approved')
  end

  test "add bug from advisory" do
    advisory = @release.errata.new_files.first
    assert_difference('FiledBug.count') do
      post :add_bug,
        :format => :json,
        :id => advisory.id,
        :bug => @idsfixed.split.last
    end
    assert_response :success
    assert advisory.bugs.map(&:id).include? @idsfixed.split.last.to_i
  end

  test "add invalid bug to advisory" do
    advisory = Errata.new_files.where(:group_id => FastTrack.all).last
    assert_not_nil advisory, 'fixture problem: expected a NEW_FILES FastTrack advisory to exist'
    post :add_bug,
      :format => :json,
      :id => advisory.id,
      :bug => Bug.with_states('MODIFIED').unfiled.first.id
    assert_response :unprocessable_entity
    assert_match %r{following acked flags}, json_response.values.join
  end

  test "remove bug from advisory" do
    advisory = Errata.find(10808)
    bug = advisory.bugs.last
    assert_difference('DroppedBug.count') do
      post :remove_bug,
        :format => :json,
        :id => advisory.id,
        :bug => bug.id.to_s
    end
    assert_response :success
    refute advisory.bugs.map(&:id).include? bug
  end

  test "add bug fetches if bug is unknown" do
    advisory = @release.errata.new_files.select{|e| e.filed_bugs.any?}.first
    bug = Bug.new(
      advisory.filed_bugs.last.bug.attributes.except(:id, :status)
    )
    bug.update_attributes(:id => 123123123, :status => 'VERIFIED')

    Bug.expects(:batch_update_from_rpc).once.with([123123123]){
      bug.save!
    }.returns([bug])

    assert_difference('FiledBug.count') do
      post :add_bug,
        :format => :json,
        :id => advisory.id,
        :bug => 123123123
      assert_response :success, response.body
    end
    advisory.reload
    assert advisory.bugs.include?(bug)
  end

  test "add bug fails if fetch cannot find the bug" do
    advisory = @release.errata.new_files.first

    Bug.expects(:batch_update_from_rpc).once.with([123123123]).returns([])

    assert_no_difference('FiledBug.count') do
      post :add_bug,
        :format => :json,
        :id => advisory.id,
        :bug => 123123123
      assert_response :bad_request, response.body
    end

    assert_match %r{\binvalid or unknown bug\b}, response.body, response.body
  end

  test "add jira issue from advisory" do
    advisory = @release.errata.new_files.first
    assert_difference('FiledJiraIssue.count') do
      post :add_jira_issue,
        :format => :json,
        :id => advisory.id,
        :jira_issue => @jira_issues_fixed.last
    end
    assert_response :success
    assert advisory.jira_issues.map(&:key).include? @jira_issues_fixed.last
  end

  test "add jira issue gives bad request if parameter missing" do
    advisory = @release.errata.new_files.first
    post :add_jira_issue,
      :format => :json,
      :id => advisory.id
    assert_response :bad_request
    assert_match %r{\bmissing jira issue\b}, response.body, response.body
  end

  test "add jira issue tries to fetch and gives bad request if referring to nonexistent JIRA issue" do
    advisory = @release.errata.new_files.first
    JiraIssue.expects(:batch_update_from_rpc).once.with(['NOTEXIST-123'], :permissive => true).returns([])
    post :add_jira_issue,
      :format => :json,
      :id => advisory.id,
      :jira_issue => 'NOTEXIST-123'
    assert_response :bad_request
    assert_match %r{\binvalid or unknown jira issue NOTEXIST-123\b}, response.body, response.body
  end

  test "add jira issue tries to fetch and succeeds if JIRA issue can be found via rpc" do
    advisory = @release.errata.new_files.first
    ji = JiraIssue.new(JiraIssue.last.attributes.merge(:key => 'FROMRPC-123', :id_jira => 9999998, :updated => Time.now, :id => nil))
    JiraIssue.expects(:batch_update_from_rpc).once.with(['FROMRPC-123'], :permissive => true){
      ji.save!
    }.returns([ji])
    post :add_jira_issue,
      :format => :json,
      :id => advisory.id,
      :jira_issue => 'FROMRPC-123'
    assert_response :success
  end

  test "add jira issue doesn't try to fetch if passed a bad key" do
    advisory = @release.errata.new_files.first
    JiraIssue.expects(:batch_update_from_rpc).never
    post :add_jira_issue,
      :format => :json,
      :id => advisory.id,
      :jira_issue => 'bad-key'
    assert_response :bad_request
    assert_match %r{\binvalid or unknown jira issue bad-key\b}, response.body, response.body
  end

  test "remove jira issue from advisory" do
    advisory = Errata.find(10808)
    jira_issue = advisory.jira_issues.last

    assert_difference('DroppedJiraIssue.count') do
      post :remove_jira_issue,
        :format => :json,
        :id => advisory.id,
        :jira_issue => jira_issue.key.to_s
    end
    assert_response :success
    refute advisory.jira_issues.map(&:key).include? jira_issue.key.to_s
  end

  test "change advisory state" do
    pass_rpmdiff_runs
    post :change_state,
      :format => :json,
      :id => rhba_async.id,
      'new_state' => State::QE
    assert_response :success
    rhba_async.reload
    assert rhba_async.status_is? State::QE
  end

  test "change docs reviewer" do
    assert_not_equal User.last, @rhea.content.doc_reviewer
    comment = "This is a test"

    post :change_docs_reviewer,
      :format => :json,
      :id => @rhea.id,
      :login_name => User.last.login_name.to_s,
      :comment => comment
    assert_response :success
    @rhea.reload
    assert_equal User.last, @rhea.content.doc_reviewer
    assert_match %r{#{comment}}, @rhea.comments.last.text
  end

  test "error on changing docs reviewer to invalid user" do
    post :change_docs_reviewer,
      :format => :json,
      :id => @rhea.id,
      :login_name => User.last.id.to_s
    assert_response :unprocessable_entity
    assert_match %r{Couldn't find User}, json_response.values.join

    post :change_docs_reviewer,
      :format => :json,
      :id => @rhea.id,
      :login_name => User.disabled.first.login_name
    assert_response :unprocessable_entity
  end

  test "embargo date is not reset on subsequent calls" do
    assert_nil @rhea.release_date

    put :update,
      :format => :json,
      :id => @rhea.id,
      :advisory => {
        'embargo_date' => '2013-03-12',
      }
    assert_response :success
    @rhea.reload
    assert_not_nil @rhea.release_date

    put :update,
      :format => :json,
      :id => @rhea.id,
      :advisory => {
        'text_ready' => 1,
      }
    assert_response :success
    @rhea.reload
    assert_not_nil @rhea.release_date
  end

  test "mangle parameters update method" do
    put :update,
      :format => :json,
      :id => @rhea.id,
      :advisory => {
        'publish_date_override' => '2013-03-12',
      }
    assert_response :success
    @rhea.reload
    assert_not_nil @rhea.publish_date_override
  end

  test "can close advisory" do
    advisory = RHBA.find(11031)
    assert_equal 'SHIPPED_LIVE', advisory.status
    advisory.update_attributes!(:closed => false)

    put :update,
      :format => :json,
      :id => advisory.id,
      :advisory => {:closed => 1}

    assert_response :success, response.body
    advisory.reload
    assert advisory.closed?
  end

  test "can open advisory" do
    advisory = RHBA.find(11031)
    assert_equal 'SHIPPED_LIVE', advisory.status
    advisory.update_attributes!(:closed => true)

    put :update,
      :format => :json,
      :id => advisory.id,
      :advisory => {:closed => 0}

    assert_response :success, response.body
    advisory.reload
    refute advisory.closed?
  end

  test "backward compatible make sure result still return errata_id field" do
    get :show, :format => :json, :id => @rhea.id

    assert_response :success
    errata = json_response('errata', @rhea.class.name.downcase)
    assert_not_nil errata['errata_id']
  end

  test "update QE assignee" do
    comment_count = @rhea.comments.count
    put :update,
      :format => :json,
      :id => @rhea.id,
      :advisory => {
        'assigned_to_email' => qa_user.login_name,
      }
    assert_response :success

    # Comment added when QE assignee is changed
    assert_equal 1+comment_count, @rhea.comments.count
    assert_match /^Changed QE owner/, @rhea.comments.last.text

    get :show,
      :format => :json,
      :id => @rhea.id
    assert_equal qa_user.id, json_response('errata', 'rhea', 'assigned_to_id')
  end

  test "error on updating QE assignee with non QE user" do
    put :update,
      :format => :json,
      :id => @rhea.id,
      :advisory => {
        'assigned_to_email' => devel_user.login_name,
      }
    assert_json({:errors => { :assigned_to_email => ["devel@redhat.com is not a QA user"] }}, :unprocessable_entity)
  end

  test "error on updating QE assignee with invalid user" do
    put :update,
      :format => :json,
      :id => @rhea.id,
      :advisory => {
        'assigned_to_email' => 'nobody@example.com',
      }
    assert_json({:errors => { :assigned_to_email => ["nobody@example.com is not a valid errata user"] }}, :unprocessable_entity)
  end

  test "can set assigned_to_email in new advisory" do
    post :create, @params.deep_merge({
      :format => :json,
      :advisory => {
        :assigned_to_email => qa_user.login_name
      }
    })
    assert_response :success
    errata = json_response('errata', 'rhba')
    assert_equal qa_user.id, errata['assigned_to_id']
  end

  test "user without createasync role cannot create ASYNC advisory" do
    auth_as devel_user
    post :create, @params.deep_merge({:format => :json})
    assert_response :unprocessable_entity
    assert_match %r{does not have permission to create ASYNC}, response.body
  end

  test "change batch" do
    erratum = Errata.find(19829)
    post :change_batch,
      :format => :json,
      :id => erratum.id,
      :batch_id => 1,
      :is_batch_blocker => true
    assert_response :success
    erratum.reload
    assert_equal 1, erratum.batch_id
    assert erratum.is_batch_blocker?
  end

  test "change batch for PUSH_READY" do
    erratum = Errata.find(10836)
    post :change_batch,
      :format => :json,
      :id => erratum.id,
      :batch_id => 1
    assert_response :unprocessable_entity
    erratum.reload
    assert erratum.batch_id.nil?
  end

  test "change batch fails for unauthorized user" do
    auth_as devel_user
    erratum = Errata.find(19829)
    post :change_batch,
      :format => :json,
      :id => erratum.id,
      :batch_id => 1
    assert_response :unauthorized
    erratum.reload
    assert erratum.batch_id.nil?
  end

  test "change batch fails for released batch" do
    erratum = Errata.find(19829)
    post :change_batch,
      :format => :json,
      :id => erratum.id,
      :batch_id => 6
    assert_response :unprocessable_entity
    assert_equal 'cannot be released', json_response('errors', 'batch').join
    erratum.reload
    assert erratum.batch_id.nil?
  end

  test "change batch fails for locked batch" do
    erratum = Errata.find(19829)
    post :change_batch,
      :format => :json,
      :id => erratum.id,
      :batch_id => 7
    assert_response :unprocessable_entity
    assert_equal 'is locked', json_response('errors', 'batch').join
    erratum.reload
    assert erratum.batch_id.nil?
  end

  test "error response updating batch using erratum update API" do
    put :update,
      :format => :json,
      :id => 19829,
      :advisory => {
        :batch_id => 2
      }
    assert_response :unprocessable_entity
    assert_equal 'Use change_batch API to set batch details', json_response['error'], json_response.inspect
    assert Errata.find(19829).batch_id.nil?
  end

  test "change batch with invalid batch name" do
    erratum = Errata.find(19707)
    post :change_batch,
      :format => :json,
      :id => erratum.id,
      :batch_name => 'no_such_batch'
    assert_response :unprocessable_entity
    assert_match %r{Couldn't find Batch with name}, response.body
  end

  test "error on change batch with mismatched release" do
    erratum = Errata.where(:group_id => 147).last
    post :change_batch,
      :format => :json,
      :id => erratum.id,
      :batch_id => 1
    assert_response :unprocessable_entity
    assert_equal 'must be for same release', json_response('errors', 'batch').join
  end

  test "clear batch" do
    erratum = Errata.find(19707)
    assert_equal 2, erratum.batch_id
    post :change_batch,
      :format => :json,
      :id => erratum.id,
      :clear_batch => true
    assert_response :success
    erratum.reload
    assert_equal nil, erratum.batch_id
  end

  test "error when incompatible parameters in change_batch request" do
    erratum = Errata.find(19707)
    assert_equal 2, erratum.batch_id
    post :change_batch,
      :format => :json,
      :id => erratum.id,
      :clear_batch => true,
      :batch_id => 1
    assert_response :bad_request
    assert_match %r{Only one of parameters}, response.body
    erratum.reload
    assert_equal 2, erratum.batch_id
  end

  test "error when no valid parameters in change_batch request" do
    erratum = Errata.find(19707)
    assert_equal 2, erratum.batch_id
    post :change_batch,
      :format => :json,
      :id => erratum.id,
      :bogus => true,
      :nonsense => 'stuff'
    assert_response :bad_request
    assert_match %r{Missing parameters}, response.body
    erratum.reload
    assert_equal 2, erratum.batch_id
  end

  test "new erratum assigned to batch if enabled for release" do
    release_name = 'RHEL-7.1.Z'
    assert Release.find_by_name(release_name).enable_batching?,
      "Release '#{release_name}' does not have batching enabled"

    type = RHBA.name
    params = @params.deep_merge({
      :format => :json,
      :release => 'RHEL-7.1.Z',
      :advisory => {
        :errata_type => type,
        :idsfixed => '1176612'
      },
    })

    assert_difference('Errata.count') do
      post :create, params
    end
    assert_response :success
    errata = json_response('errata', type.downcase)
    assert_equal Errata.last.id , errata['id']
    assert_not_nil errata['batch_id']
  end

  test "can set quality_responsibility_name in new advisory" do
    qa_responsibility = QualityResponsibility.find_by_id(104);
    post :create, @params.deep_merge({
      :format => :json,
      :advisory => {
        :quality_responsibility_name => qa_responsibility.name
      }
    })
    assert_response :success
    errata = json_response('errata', 'rhba')
    assert_equal qa_responsibility.id, errata['quality_responsibility_id']
  end

  test "set quality_responsibility_name based on user's input not package's default one" do
    qa_responsibility = QualityResponsibility.find_by_id(104);
    package = Package.find_by_name('FreeWnn');
    post :create, @params.deep_merge({
      :format => :json,
      :advisory => {
        :quality_responsibility_name => qa_responsibility.name,
        :synopsis => 'FreeWnn'
      }
    })
    assert_response :success
    errata = json_response('errata', 'rhba')
    assert_not_equal package.quality_responsibility.id, errata['quality_responsibility_id']
    assert_equal qa_responsibility.id, errata['quality_responsibility_id']
  end

  test "error when setting invalid quality_responsibility_name in new advisory" do
    post :create, @params.deep_merge({
      :format => :json,
      :advisory => {
        :quality_responsibility_name => 'Invalid QE'
      }
    })
    assert_json({:errors => { :quality_responsibility_name => ["'Invalid QE' is not a valid qe group name."]}}, :unprocessable_entity)
  end

  test "set package's quality_responsibility if not explicitly specify the value of quality_responsibility_name" do
    qr = QualityResponsibility.find_by_name('BaseOS QE - Applications')
    pkg = Package.find_by_name('javassist')
    assert_equal qr, pkg.quality_responsibility
    post :create, @params.deep_merge({
      :format => :json,
      :advisory => {
        :synopsis => 'javassist'
      }
    })
    errata = json_response('errata', 'rhba')
    assert_equal qr.id, errata['quality_responsibility_id']
  end

  test "update QE group" do
    qa_responsibility = QualityResponsibility.find_by_id(104);

    assert_difference('@rhea.comments.count', 1) do
      put :update,
        :format => :json,
        :id => @rhea.id,
        :advisory => {
          'quality_responsibility_name' => qa_responsibility.name,
        }
        assert_response :success
    end
    assert_match /^Changed QE group/, @rhea.comments.last.text

    get :show,
      :format => :json,
      :id => @rhea.id
    assert_equal qa_responsibility.id, json_response('errata', 'rhea', 'quality_responsibility_id')
  end

  def assert_create_type_of_advisory(type)
    params = @params.deep_merge({:format => :json, :advisory => {:errata_type => type }})
    assert_difference('Errata.count') do
      post :create, params
    end
    assert_response :success, "creation of #{type} failed."
    errata = json_response('errata', type.downcase)
    assert_equal Errata.last.id , errata['id']
    assert_match %r{#{@text}}   , errata['synopsis']
    assert_equal @user.id       , errata['manager_id']
    Errata.last
  end

  #
  # TODO:
  # errata.content
  #
  def assert_clone_advisory(advisory, type='rhba', params=nil)
    params ||= {
      :format => :json,
      :id => advisory.id,
      :advisory => {:idsfixed => @all_issues.join(' '), :synopsis  => @text }
    }
    assert_difference('Errata.count') do
      post :clone, params
    end
    assert_response :success
    result = json_response('errata', type)
    assert_equal Errata.last.id, result['id'], Errata.last.id
    assert_match %r{#{@text}}, result['synopsis']
    Errata.last
  end

  def assert_json(expected_result, status)
    assert_response status
    assert_equal expected_result.to_json, response.body
  end

  def rel_prep_unrequested_rhsa
    Errata.find(11138)
  end

  def rel_prep_requested_rhsa
    Errata.find(11133)
  end

  def rel_prep_approved_rhsa
    Errata.find(19463)
  end

  def rel_prep_rhba
    Errata.find(11118)
  end
end


class Api::V1::ErratumControllerBrewBuildsTest < ActionController::TestCase

  tests Api::V1::ErratumController
  include TestCaseHelpers

  setup do
    auth_as admin_user
    #
    # This advisory has valid tagged builds and is in NEW_FILES
    #
    @advisory = Errata.find(11036)

    # A build with RPMs
    @rpm_build = BrewBuild.find(428959)

    # Use cached product listings only
    ProductListing.stubs(:get_brew_product_listings => {})
  end

  test "remove brew build from advisory by nvr" do
    build = @advisory.brew_builds.last.nvr
    try_to_remove_build(@advisory, build)
    assert_response :success

    # It's OK to request removing the same build again
    try_to_remove_build(@advisory, build)
    assert_response :success
  end

  test "add and remove builds only from advisory in NEW_FILES" do
    advisory = Errata.find(11152) # in QE
    post :add_build,
      :format => :json,
      :id => advisory,
      :nvr => BrewBuild.first.nvr,
      :product_version => advisory.available_product_versions.last.name
    assert_response :unprocessable_entity
    assert_match %r{must be NEW_FILES}, json_response.values.join

    try_to_remove_build(advisory, advisory.brew_builds.last.nvr)
    assert_response :unprocessable_entity
    assert_match %r{must be NEW_FILES}, json_response.values.join
  end

  test "add improper tagged brew build" do
    Brew.any_instance.expects(:list_tags).returns(['RHEL-2000'])
    e = Errata.find(16397)
    post :add_build,
      :format => :json,
      :id => e.id,
      :nvr => @rpm_build.nvr,
      :product_version => e.available_product_versions.last.name
    assert_response :unprocessable_entity
    assert_match %r{does not have.*following tags}, json_response.values.join
  end

  test "add unknown build which raises error" do
    BrewBuild.expects(:find_by_nvr).returns(nil)
    Brew.any_instance.expects(:getBuild).returns(nil)
    try_to_add_build(@advisory, 'libbeer-1.1.35-1.el6rhci')
    assert_response :unprocessable_entity
    assert_match %r{No such build}, json_response.values.join
  end

  test "error response trying to add a build with no build specified" do
    [ [ :add_build, {} ],
      [ :add_builds, {} ],
      [ :add_builds, { :_json => [{}] } ],
    ].each do |action, extra_params|
      post action, { :format => :json, :id => @advisory.id }.merge(extra_params)
      assert_response :error
      assert_equal 'ERROR: build missing id or nvr', json_response['error'], json_response.inspect
    end

  end

  test "adding an empty list of builds succeeds but does nothing" do
    assert_no_difference('ErrataBrewMapping.count') do
      post :add_build, { :format => :json, :id => @advisory.id, :_json => [] }
      assert_response :success
    end
  end

  test "add unknown build successfully" do
    build_data = {
      "state"             => 1,
      "package_name"      => "libbeer",
      "epoch"             => nil,
      "release"           => "1.el6rhci.megadeps.3",
      "id"                => 313599,
      "nvr"               => "libbeer-1.1.35-1.el6rhci.megadeps.3",
      "version"           => "1.1.35",
    }
    rpms = [{
      "arch"               => "src",
      "epoch"              => nil,
      "nvr"               => "libbeer-1.1.35-1.el6rhci.megadeps.3",
      "id"                 => 3042504,
    }]
    Brew.any_instance.expects(:getBuild).returns(build_data)
    Brew.any_instance.expects(:listBuildRPMs).returns(rpms)
    Brew.any_instance.expects(:build_is_properly_tagged?).returns(true)
    Brew.any_instance.expects(:listArchives).at_least_once.returns([])

    assert_difference("BrewBuild.count") do
      try_to_add_build(@advisory, 'libbeer-1.1.35-1.el6rhci')
    end
    assert_response :success
  end

  test "add brew build without srpm should trigger rpmdiff scheduling error" do
    Rails.stubs(:logger).returns(MockLogger)
    Brew.any_instance.expects(:list_tags).with(
      instance_of(BrewBuild)).returns(@advisory.release.brew_tags.map(&:name))

    @rpm_build.srpm.destroy
    try_to_add_build(@advisory, @rpm_build.nvr)

    expected_message = "Validation failed: Can't schedule RPMDiff run for " +
      "'#{@rpm_build.nvr}' because this brew build doesn't contain SRPM."

    assert MockLogger.log.include?(expected_message)
  end

  test "add brew build with invalid product version" do
    advisory = Errata.find(11142)
    Brew.any_instance.expects(:build_is_properly_tagged?).never

    post :add_build,
      :format => :json,
      :id => advisory.id,
      :nvr => @rpm_build.nvr,
      :product_version => 'RHEL-5.6.Z'
    assert_response :unprocessable_entity
    assert_match %r{Product version RHEL-5.6.Z can't be used with this advisory}, json_response.values.uniq.flatten.join(' ')
  end

  test "add brew build with newer rpm than the released rpm" do
    channel_links = [ChannelLink.first]
    Brew.any_instance.expects(:list_tags).with(
      instance_of(BrewBuild)).returns(@advisory.release.brew_tags.map(&:name))
    ProductVersion.any_instance.expects(:supports_rhn?).once.returns(true)
    ProductVersion.any_instance.expects(:supports_cdn?).once.returns(false)
    ProductVersion.any_instance.expects(:channel_links).once.returns(channel_links)
    results = { :list => ['some_rpm1', 'some_rpm2'], :error_messages => [] }
    ReleasedPackage.expects(:last_released_packages_by_variant_and_arch).once.returns(results)

    assert_difference("ErrataBrewMapping.count", 1) do
      try_to_add_build(@advisory, @rpm_build.nvr)
    end
    assert_response :success
  end

  test "add brew build with older/equal rpm than the released rpm" do
    channel_links  = [ChannelLink.first]
    cdn_repo_links = [CdnRepoLink.first]

    build = @rpm_build
    Brew.any_instance.expects(:build_is_properly_tagged?).once.returns(true)
    ProductVersion.any_instance.expects(:supports_rhn?).once.returns(true)
    ProductVersion.any_instance.expects(:supports_cdn?).once.returns(true)
    ProductVersion.any_instance.expects(:channel_links).once.returns(channel_links)
    ProductVersion.any_instance.expects(:cdn_repo_links).once.returns(cdn_repo_links)

    expected_error_messages = ["Unable to add build '#{build.nvr}'."]
    error_message = "Build 'some_build' has newer or equal version of 'some_released.rpm' in 'some_variant'."
    expected_error_messages << error_message
    results = { :list => [], :error_messages => [error_message] }

    [channel_links, cdn_repo_links].flatten.each do |link|
      ReleasedPackage.expects(:last_released_packages_by_variant_and_arch).once.with(
        link.variant, instance_of(Arch), build.brew_rpms, {:validate_version => true}).returns(results)
    end

    assert_no_difference("ErrataBrewMapping.count") do
      try_to_add_build(@advisory, build.nvr)
    end

    assert_response :unprocessable_entity
    assert_match %r{#{expected_error_messages.join(' ')}}, json_response.values.uniq.flatten.join(' ')
  end

  test "product listing is not valid" do
    Brew.any_instance.expects(:list_tags).with(
      instance_of(BrewBuild)).returns(@advisory.release.brew_tags.map(&:name))
    ProductListing.expects(:find_or_fetch).raises(XMLRPC::FaultException, "server error")

    try_to_add_build(@advisory, @rpm_build.nvr)

    assert_response :unprocessable_entity
  end

  test "add brew build by nvr" do
    Brew.any_instance.expects(:list_tags).with(
      instance_of(BrewBuild)).returns(@advisory.release.brew_tags.map(&:name))

    assert_difference("ErrataBrewMapping.count") do
      try_to_add_build(@advisory, @rpm_build.nvr)
    end

    assert_response :success

    #
    # Can't add the same build twice!
    #
    assert_no_difference("ErrataBrewMapping.count") do
      try_to_add_build(@advisory, @rpm_build.nvr)
    end
    assert_response :unprocessable_entity
    assert_match %r{Build.*already added}, json_response.values.join(' ')
  end

  # bug 1141564
  test "adding a build obsoletes older build of the same package" do
    e = Errata.find(11142)
    old_build = BrewBuild.find_by_nvr!('kdenetwork-3.5.4-10.el5_6.1')
    new_build = BrewBuild.find_by_nvr!('kdenetwork-3.5.4-11.el5_6.1')

    assert e.brew_builds.include?(old_build), 'fixture problem'
    refute e.brew_builds.include?(new_build), 'fixture problem'

    # make sure we're using the same PV for the new build
    have_pv = e.build_mappings.map(&:product_version).to_a
    assert_equal [165], have_pv.map(&:id)

    # have to fake it as available, otherwise it's not... (bad fixture?)
    e.class.any_instance.stubs(:available_product_versions => have_pv)

    Brew.any_instance.expects(:list_tags).with(new_build).returns(%w[RHEL-5.6-Z-candidate])

    assert_difference('ErrataBrewMapping.count', 1) do
      post(:add_build,
        :format => :json,
        :id => e.id,
        :nvr => new_build.nvr,
        :product_version => ProductVersion.find(165).name)
      assert_response :success, response.body
    end

    e.reload

    # old build should be replaced with new build
    assert e.brew_builds.include?(new_build)
    refute e.brew_builds.include?(old_build)
  end

  test "add build to pdc release" do
    Brew.any_instance.stubs(:build_is_properly_tagged? => true)

    errata = Errata.find(21131)
    new_build = BrewBuild.find_by_nvr!('ceph-10.2.5-26.el7cp')

    assert errata.available_pdc_releases.count == 2
    VCR.use_cassette('pdc_advisory_api_add_build') do
     VCR.use_cassettes_for(:pdc_ceph21) do
      assert_difference('PdcErrataReleaseBuild.count') do
        post :add_build,
          :format => :json,
          :id => errata.id,
          :nvr => new_build.nvr,
          :pdc_release => errata.pdc_releases.first.pdc_id
        assert_response :success, response.body
      end
     end
    end
  end

  test "add builds to pdc release" do
    Brew.any_instance.stubs(:build_is_properly_tagged? => true)
    errata = Errata.find(21131)
    new_build = BrewBuild.find_by_nvr!('ceph-10.2.5-26.el7cp')

    assert errata.available_pdc_releases.count == 2
    VCR.use_cassette('pdc_advisory_api_add_builds') do
     VCR.use_cassettes_for(:pdc_ceph21) do
      assert_difference('PdcErrataReleaseBuild.count') do
        post :add_builds,
          :format => :json,
          :id => errata.id,
          :build => new_build.nvr,
          :product_version => errata.pdc_releases.first.pdc_id
        assert_response :success, response.body
      end
     end
    end
  end

  test "add builds to pdc release with wrong input" do
    Brew.any_instance.stubs(:build_is_properly_tagged? => true)
    errata = Errata.find(21131)
    new_build = BrewBuild.find_by_nvr!('ceph-10.2.5-26.el7cp')

    assert errata.available_pdc_releases.count == 2
    assert_no_difference('PdcErrataReleaseBuild.count') do
      post :add_builds,
        :format => :json,
        :id => errata.id,
        :build => new_build.nvr,
        :pdc_release => errata.pdc_releases.first.pdc_id,
        :product_version => errata.pdc_releases.first.pdc_id
    end
    assert_response :unprocessable_entity
  end

  test "not allowed to add builds to text only advisories" do
    #
    # Note: it doesn't matter that we we just pick a product version out
    # of the blue, since the code checks for the text_only type first,
    # before it even checks the product versions.
    #
    advisory = Errata.where('text_only = 1').new_files.last

    post :add_build,
      :format => :json,
      :id => advisory.id,
      :nvr => @rpm_build.nvr,
      :product_version => ProductVersion.first.name
    assert_response :unprocessable_entity
    assert_match %r{Can not add.*text only}, json_response.values.join('')
  end

  test 'reload builds' do
    e = Errata.find(7519)

    post :reload_builds,
      :format => :json,
      :id => e.id
    assert_response :created
    assert_match %r{/api/v1/job_trackers/\d+$}, response.location

    id = json_response('job_tracker', 'id').to_i
    tracker = JobTracker.find(id)
    assert_equal "Reload Builds for #{e.advisory_name}", tracker.name
  end

  test 'reload builds redirect' do
    e = Errata.find(7519)

    post :reload_builds,
      :format => :json,
      :id => e.id,
      :redirect => 1
    assert_response :redirect
    pattern = %r{/job_trackers/(\d+)$}
    assert_match pattern, response.location
    response.location =~ pattern

    id = $1.to_i
    tracker = JobTracker.find(id)
    assert_equal "Reload Builds for #{e.advisory_name}", tracker.name
  end

  test 'reload builds should fail if no builds to reload' do
    e = Errata.find(7519)
    e.class.any_instance.expects(:build_mappings).once.returns([])

    assert_no_difference('JobTracker.count') do
      post :reload_builds,
        :format => :json,
        :id => e.id
    end
    assert_response :unprocessable_entity
    assert_equal "Advisory '#{e.advisory_name}' has no builds to reload.", json_response["error"]
  end

  test "reload builds redirect should fail and redirect back if no builds to reload" do
    e = Errata.find(7519)
    e.class.any_instance.expects(:build_mappings).once.returns([])
    # Fake a referrer so that redirect_to :back won't raise error
    request.env['HTTP_REFERER'] = rhba_path

    assert_no_difference('JobTracker.count') do
      post :reload_builds,
        :format => :json,
        :id => e.id,
        :redirect => 1
    end
    assert_response :redirect
    assert_equal rhba_path, response.location
  end

  test "reload builds without product listings only" do
    e = Errata.find(7519)
    # Delete product listings for the first 2 mappings, so that there are something to
    # reload later
    e.build_mappings.first(2).each do |m|
      ProductListingCache.
        where(:product_version_id => m.product_version_id, :brew_build_id => m.brew_build_id).
        delete_all
    end

    assert_difference('Delayed::Job.count', 2) do
      post :reload_builds,
        :format => :json,
        :id => e.id,
        :no_rpm_listing_only => true
    end
    assert_response :created
    assert_match %r{/api/v1/job_trackers/\d+$}, response.location

    id = json_response('job_tracker', 'id').to_i
    tracker = JobTracker.find(id)
    assert_equal "Reload Builds for #{e.advisory_name}", tracker.name
    assert_equal "Reload brew builds for this advisory that have no product listings.", tracker.description
  end

  test 'add non-RPM files to advisory' do
    e = Errata.find(16397)

    # pretend all tags are valid
    Brew.any_instance.stubs(:build_is_properly_tagged? => true)

    build1 = BrewBuild.find_by_nvr!('CloudForms-3.0-20140109.3')
    build2 = BrewBuild.find_by_nvr!('rhel-server-x86_64-ec2-starter-6.5-8')
    pv1 = ProductVersion.find_by_name!('RHEL-5-JBEAP-6')
    pv2 = ProductVersion.find_by_name!('RHEL-6-JBEAP-6')

    assert_difference('ErrataBrewMapping.count', 4) do
      post(:add_builds,
        :format => :json,
        :id => e.id,
        :_json => [
          {:build => build1.nvr, :product_version => pv1.name, :file_types => %w[qcow2]},
          {:build => build1.id,  :product_version => pv2.name, :file_types => %w[ova]},
          {:build => build2.nvr, :product_version => pv1.name, :file_types => %w[xml raw]},
        ])
      assert_response :success, response.body
    end

    (qcow2,ova,xml,raw) = %w[qcow2 ova xml raw].
      map{|name| BrewArchiveType.find_by_name!(name)}
    cmp_keys = %w[brew_build_id errata_main_id product_version_id brew_archive_type_id]

    mappings = ErrataBrewMapping.order('id DESC').limit(4).to_a
    assert_equal([
      {:brew_archive_type_id => ova.id,   :brew_build_id => build1.id, :product_version_id => pv2.id},
      {:brew_archive_type_id => qcow2.id, :brew_build_id => build1.id, :product_version_id => pv1.id},
      {:brew_archive_type_id => raw.id,   :brew_build_id => build2.id, :product_version_id => pv1.id},
      {:brew_archive_type_id => xml.id,   :brew_build_id => build2.id, :product_version_id => pv1.id},
      ],
      mappings.
        sort_by{|m| [m.brew_archive_type.name, m.brew_build.nvr, m.product_version.name]}.
        map{|m| m.attributes.slice(*cmp_keys).symbolize_keys}
    )
  end

  test 'add single build with non-RPM files to advisory' do
    e = Errata.find(16397)

    # pretend all tags are valid
    Brew.any_instance.stubs(:build_is_properly_tagged? => true)

    build = BrewBuild.find_by_nvr!('CloudForms-3.0-20140109.3')
    pv = ProductVersion.find_by_name!('RHEL-5-JBEAP-6')

    assert_difference('ErrataBrewMapping.count', 1) do
      post(:add_builds,
        :format => :json,
        :id => e.id,
        :build => build.nvr,
        :product_version => pv.name,
        :file_types => %w[qcow2]
      )
      assert_response :success, response.body
    end

    mapping = ErrataBrewMapping.order('id DESC').first
    assert_equal pv, mapping.product_version
    assert_equal build, mapping.brew_build
    assert_equal e, mapping.errata
    assert_equal 'qcow2', mapping.brew_archive_type.name
  end

  #BZ 1159249
  test "prevent to add same brew build twice with different type" do
    # pretend all tags are valid
    Brew.any_instance.stubs(:build_is_properly_tagged? => true)

    e = Errata.find(16409)
    e.change_state!('NEW_FILES', devel_user)
    build = BrewBuild.find_by_nvr!('spice-client-msi-3.4-4')
    pv = ProductVersion.find_by_name!('RHEL-6-RHEV-S-3.4')

    #clean the exist build
    try_to_remove_build(e, build)
    assert_response :success

    #first create, it should be successful
    assert_difference('ErrataBrewMapping.count') do
      post :add_build,
        :format => :json,
        :id => e.id,
        :nvr => build.nvr,
        :product_version => pv,
        :file_types => %w[rpm cab]
      assert_response :success, response.body
    end

    #same advisory with different type, it can't created successful
    assert_no_difference('ErrataBrewMapping.count') do
      post :add_build,
        :format => :json,
        :id => e.id,
        :nvr => build.nvr,
        :product_version => pv,
        :file_types => %w[msi]
      assert_response :unprocessable_entity
      assert_match %r{Build.*already added}, json_response.values.join(' ')
    end
  end

  test 'adding builds automatically enables multi-products support' do
    Brew.any_instance.stubs(:build_is_properly_tagged? => true)
    e = Errata.find(20291)
    e.build_mappings.update_all(:current => false)
    e.current_files.each{|f| f.update_attributes(:current => false)}

    # Assuming this hasn't beet set.
    e.update_attribute(:supports_multiple_product_destinations, nil)
    build = BrewBuild.find_by_nvr('libvirt-0.10.2-46.el6_6.6')
    pv = ProductVersion.find_by_name('RHEL-6.6.z')

    # This package has some mapped product_versions
    assert MultiProductMap.mapped_product_versions(pv, build.package).any?

    assert_difference('ErrataBrewMapping.count', 1) do
      post :add_build,
           :format => :json,
           :id => e.id,
           :nvr => build.nvr,
           :product_version => pv,
           :file_types => %w[rpm]
      assert_response :success, response.body
    end

    e.reload
    # Automatically enabled
    assert e.supports_multiple_product_destinations?
  end

  test 'add docker build' do
    # pretend all tags are valid
    Brew.any_instance.stubs(:build_is_properly_tagged? => true)

    # Need to put this advisory back to NEW_FILES to add build
    e = Errata.find(21100)
    e.change_state!('REL_PREP', admin_user)
    e.change_state!('NEW_FILES', admin_user)

    build = BrewBuild.find_by_nvr!('rhel-server-docker-7.1-3')
    pv = ProductVersion.find_by_name!('RHEL-7.1.Z')

    # clean the existing build
    try_to_remove_build(e, build)
    assert_response :success

    # advisory no longer has docker images
    refute e.reload.has_docker?

    # first create, should be successful
    assert_difference('ErrataBrewMapping.count') do
      post :add_builds,
        :format => :json,
        :id => e.id,
        :build => build.nvr,
        :product_version => pv,
        :file_types => %w[tar]
      assert_response :success, response.body
    end

    # advisory now has a docker image
    assert e.reload.has_docker?

    # add again, should fail
    assert_no_difference('ErrataBrewMapping.count') do
      post :add_builds,
        :format => :json,
        :id => e.id,
        :build => build.nvr,
        :product_version => pv,
        :file_types => %w[tar]
      assert_response :unprocessable_entity
      assert_match %r{Build.*already added}, json_response.values.join(' ')
    end

    # add some RPMs, should fail
    assert_no_difference('ErrataBrewMapping.count') do
      post :add_builds,
        :format => :json,
        :id => e.id,
        :build => 'kexec-tools-2.0.7-19.el7',
        :product_version => pv,
        :file_types => %w[rpm]
      assert_response :unprocessable_entity
      assert_equal 'Docker image builds and RPM builds cannot be added to the same advisory', json_response('error')
    end
  end

  # See: bz1333752
  test "update advisory with jira matching bug alias" do
    synopsis = 'This is a test synopsis'
    errata_id = 20836

    # This JIRA issue has a key that's also a bugzilla alias
    jira_issue = JiraIssue.find(1010)
    assert Bug.with_alias(jira_issue.key).exists?

    # Add JIRA issue to the advisory
    FiledJiraIssue.create(:errata_id => errata_id, :jira_issue => jira_issue)

    put :update,
      :format => :json,
      :id => errata_id,
      :advisory => {
        'synopsis' => synopsis
      }
    assert_response :success

    get :show,
      :format => :json,
      :id => errata_id
    assert_equal synopsis, json_response('errata', 'rhba', 'synopsis')
  end

  test "remove brew build from pdc advisory by nvr" do
   VCR.use_cassettes_for(:pdc_ceph21) do
    e = Errata.find(21131)
    build = e.brew_builds.first.nvr
    try_to_remove_build(e, build)
    assert_response :success, response.body

    # It's OK to request removing the same build again
    try_to_remove_build(e, build)
    assert_response :success, response.body
   end
  end

  test 'get variant RPM files' do
    errata = Errata.find 20291
    nvr = 'libvirt-0.10.2-46.el6_6.6'
    assert errata.supports_multiple_product_destinations?
    get :get_variant_rpms,
        :format => :json,
        :id => errata
    assert_response :success, response.body

    files = json_response(nvr, 'variant_files', )
    mapped_files = json_response(nvr, 'mapped_variant_files', )

    assert_equal ["libvirt-debuginfo-0.10.2-46.el6_6.6.i686.rpm",
                  "libvirt-lock-sanlock-0.10.2-46.el6_6.6.x86_64.rpm",
                  "libvirt-devel-0.10.2-46.el6_6.6.x86_64.rpm",
                  "libvirt-debuginfo-0.10.2-46.el6_6.6.x86_64.rpm",
                  "libvirt-devel-0.10.2-46.el6_6.6.i686.rpm"],
                 files['6Client-optional']
    assert_equal ['libvirt-lock-sanlock-0.10.2-46.el6_6.6.x86_64.rpm'],
                 mapped_files['6Server-RHS-Server-3']
  end

  def try_to_add_build(advisory, nvr)
    # (Because we might get false positives if advisory has multiple product versions)
    assert advisory.available_product_versions.count == 1
    post :add_build,
      :format => :json,
      :id => advisory.id,
      :nvr => nvr,
      :product_version => advisory.product_versions.first.name
  end

  def try_to_remove_build(advisory, nvr)
    post :remove_build,
      :format => :json,
      :id => advisory.id,
      :nvr => nvr
  end

end


