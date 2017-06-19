require 'test_helper'

class SecurityApprovalTest < ActiveSupport::TestCase
  def set_security_approved_test(opts={})
    with_current_user(opts[:user]) do
      e = opts[:errata]
      e.security_approved = opts[:value]
      if opts[:expected_errors]
        refute e.save
        assert_equal opts[:expected_errors], e.errors.full_messages
        return e
      end

      comment_text = opts[:expected_comment]
      assert_difference('SecurityApprovalComment.count', comment_text ? 1 : 0) do
        e.save!
      end
      if comment_text
        assert_equal comment_text, e.comments.last.text
      end

      return e
    end
  end

  def simple_request_approval_test
    e = set_security_approved_test :user => devel_user,
      :errata => rel_prep_unrequested_rhsa,
      :value => false,
      :expected_comment => 'Product Security approval requested.'
    assert e.security_approval_requested?
    refute e.security_approved?
    e
  end

  test 'devel user can request approval' do
    simple_request_approval_test
  end

  test 'security approval can be requested from QE state' do
    e = qe_rhsa
    e = set_security_approved_test :user => devel_user,
      :errata => e,
      :value => false,
      :expected_comment => 'Product Security approval requested.'
    assert e.security_approval_requested?
    refute e.security_approved?
  end

  test 'removing docs approval rescinds security approval' do
    with_current_user(docs_user) do
      e = rel_prep_approved_rhsa
      assert e.security_approved?
      assert e.docs_approved?
      e.disapprove_docs!
      refute e.docs_approved?
      refute e.security_approved?
    end
  end

  test 'removing docs approval as secalert user does not rescind security approval' do
    with_current_user(secalert_user) do
      e = rel_prep_approved_rhsa
      assert e.security_approved?
      assert e.docs_approved?
      e.disapprove_docs!
      refute e.docs_approved?
      assert e.security_approved?
    end
  end

  test 'doc approval for REL_PREP automatically requests security approval' do
    e = rel_prep_unrequested_rhsa
    e.disapprove_docs!
    refute e.docs_approved?
    refute e.security_approval_requested?
    e.approve_docs!
    assert e.security_approval_requested?
  end

  test 'pdc advisory doc approval for REL_PREP automatically requests security approval' do
    e = Errata.find(20000)
    e.disapprove_docs!
    refute e.docs_approved?
    refute e.security_approval_requested?
    e.approve_docs!
    assert e.security_approval_requested?
  end

  test 'requesting approval sends a qpid message' do
    MessageBus::SendMessageJob.expects(:enqueue).once.with do |msg,key,is_embargoed|
      assert_equal nil, msg['from']
      assert_equal false, msg['to']
      assert_equal 'activity.security_approved', key
      true
    end

    ActiveRecord::Base.transaction do
      simple_request_approval_test
    end
  end

  test 'readonly user cannot request approval' do
    set_security_approved_test :user => read_only_user,
      :errata => rel_prep_unrequested_rhsa,
      :value => false,
      :expected_errors => ['Security approved cannot be requested by ro@redhat.com']
  end

  test 'devel user cannot approve' do
    set_security_approved_test :user => devel_user,
      :errata => rel_prep_requested_rhsa,
      :value => true,
      :expected_errors => ['Security approved cannot be granted by devel@redhat.com']
  end

  def simple_approve_test
    e = set_security_approved_test :user => secalert_user,
      :errata => rel_prep_requested_rhsa,
      :value => true,
      :expected_comment => 'Product Security has APPROVED this advisory.'
    refute e.security_approval_requested?
    assert e.security_approved?
  end

  test 'secalert user can approve' do
    simple_approve_test
  end

  test 'approving sends a qpid message' do
    MessageBus::SendMessageJob.expects(:enqueue).once.with do |msg,key,is_embargoed|
      assert_equal false, msg['from']
      assert_equal true, msg['to']
      assert_equal 'activity.security_approved', key
      true
    end

    ActiveRecord::Base.transaction do
      simple_approve_test
    end
  end

  def simple_disapprove_test
    e = set_security_approved_test :user => devel_user,
      :errata => rel_prep_approved_rhsa,
      :value => nil,
      :expected_comment => [
        "Product Security approval rescinded.\n",
        "#{SecurityWorkflow::RESCIND_NOTE}.",
      ].join("\n")
    refute e.security_approval_requested?
    refute e.security_approved?
  end

  test 'devel user can disapprove' do
    simple_disapprove_test
  end

  test 'disapproving sends a qpid message' do
    MessageBus::SendMessageJob.expects(:enqueue).once.with do |msg,key,is_embargoed|
      assert_equal true, msg['from']
      assert_equal nil, msg['to']
      assert_equal 'activity.security_approved', key
      true
    end

    ActiveRecord::Base.transaction do
      simple_disapprove_test
    end
  end

  test 'readonly user cannot disapprove' do
    set_security_approved_test :user => read_only_user,
      :errata => rel_prep_approved_rhsa,
      :value => nil,
      :expected_errors => ['Security approved cannot be rescinded by ro@redhat.com']
  end

  test 'cannot request approval from wrong state' do
    set_security_approved_test :user => devel_user,
      :errata => new_files_rhsa,
      :value => false,
      :expected_errors => ['Security approved cannot be requested while in NEW_FILES']
  end

  test 'cannot directly go to approved' do
    set_security_approved_test :user => secalert_user,
      :errata => rel_prep_unrequested_rhsa,
      :value => true,
      :expected_errors => ['Security approved transition invalid: not requested => approved']
  end

  test 'cannot go from approved to requested' do
    set_security_approved_test :user => secalert_user,
      :errata => rel_prep_approved_rhsa,
      :value => false,
      :expected_errors => ['Security approved transition invalid: approved => requested']
  end

  test 'RHSA cannot go to PUSH_READY without approval' do
    e = rel_prep_requested_rhsa
    error = assert_raises(ActiveRecord::RecordInvalid) do
      e.change_state!('PUSH_READY', releng_user)
    end
    assert_match /must have Product Security approval/, error.message
  end

  test 'RHSA can go to PUSH_READY with approval' do
    e = rel_prep_approved_rhsa
    e.change_state!('PUSH_READY', releng_user)
    # and it should still be approved
    e.reload
    assert e.security_approved?
  end

  test 'RHSA can go to QE and maintain approval' do
    e = rel_prep_approved_rhsa
    e.change_state!('QE', releng_user)
    # and it should still be approved
    e.reload
    assert e.security_approved?
  end

  test 'RHBA can go to PUSH_READY without approval' do
    e = rel_prep_rhba
    refute e.security_approved?
    e.change_state!('PUSH_READY', releng_user)
  end

  def update_advisory(opts)
    e = opts[:errata]
    with_current_user(opts[:user]) do
      # This is a bit lame... some kinds of updates _must_ go via
      # AdvisoryForm in order for business logic to function
      # correctly, while other kinds of updates cannot be made via
      # AdvisoryForm.  Just always pass a form, the caller can access
      # the real advisory via the form when necessary for non-form
      # updates.
      form = UpdateAdvisoryForm.new(opts[:user], :id => e.id)
      ActiveRecord::Base.transaction do
        opts[:update].call(form)
        form.save!
      end
    end
    e.reload
  end

  def security_invalidate_test(opts = {})
    e = opts[:errata]

    assert e.security_approved?

    latest_comment_id = e.comments.pluck('max(id)').first
    update_advisory(opts)

    refute e.security_approved?
    refute e.security_approval_requested?

    created_comments = e.comments.where('id > ?', latest_comment_id).to_a.map(&:text)
    assert created_comments.length >= 1
    assert created_comments.include?(opts[:expected_comment]), created_comments.join("\n\n")

    e
  end

  test 'dropping a bug removes approval' do
    e = rel_prep_approved_rhsa

    remove_bug = Bug.find(680269)
    assert e.bugs.include?(remove_bug), 'fixture problem - missing filed bug'

    security_invalidate_test :errata => e,
      :user => secalert_user,
      :expected_comment => [
        "Product Security approval rescinded due to changed bugs.\n",
        "#{SecurityWorkflow::RESCIND_NOTE}.",
      ].join("\n"),
      :update => lambda{|form| form.bugs.remove(remove_bug.id)}
  end

  test 'filing a bug removes approval' do
    e = rel_prep_approved_rhsa
    add_bug = Bug.find(698060)

    security_invalidate_test :errata => e,
      :user => secalert_user,
      :expected_comment => [
        "Product Security approval rescinded due to changed bugs.\n",
        "#{SecurityWorkflow::RESCIND_NOTE}.",
      ].join("\n"),
      :update => lambda{|form| form.bugs.append(add_bug.id)}
  end

  test 'dropping a JIRA issue removes approval' do
    e = rel_prep_approved_rhsa
    remove = JiraIssue.find_by_key!('WFK2-139')
    assert e.jira_issues.include?(remove), 'fixture problem - missing filed issue'

    security_invalidate_test :errata => e,
      :expected_comment => [
        "Product Security approval rescinded due to changed JIRA issues.\n",
        "#{SecurityWorkflow::RESCIND_NOTE}.",
      ].join("\n"),
      :user => secalert_user,
      :update => lambda{|form| form.jira_issues.remove(remove.key)}
  end

  test 'filing a JIRA issue removes approval' do
    e = rel_prep_approved_rhsa
    add = JiraIssue.find_by_key!('WFLY-326')

    security_invalidate_test :errata => e,
      :user => secalert_user,
      :expected_comment => [
        "Product Security approval rescinded due to changed JIRA issues.\n",
        "#{SecurityWorkflow::RESCIND_NOTE}.",
      ].join("\n"),
      :update => lambda{|form| form.jira_issues.append(add.key)}
  end

  test 'docs change removes approval' do
    e = rel_prep_approved_rhsa

    security_invalidate_test :errata => e,
      :user => releng_user,
      :expected_comment => [
        "Product Security approval rescinded due to a docs update.\n",
        "#{SecurityWorkflow::RESCIND_NOTE}.",
      ].join("\n"),
      :update => lambda{|form|
        form.params[:advisory] = {:topic => "#{form.topic} plus some more"}
        form.update_attributes
      }
  end

  test 'docs change by secalert user removes docs approval only' do
    e = rel_prep_approved_rhsa

    assert e.docs_approved?
    update_advisory :errata => e,
      :user => secalert_user,
      :update => lambda{|form|
        form.params[:advisory] = {:topic => "#{form.topic} plus some more"}
        form.update_attributes
      }

    refute e.docs_approved?
    assert e.security_approved?
  end

  test 'changing state back to NEW_FILES removes approval' do
    e = rel_prep_approved_rhsa

    security_invalidate_test :errata => e,
      :user => secalert_user,
      :expected_comment => [
        "Product Security approval rescinded due to status change.\n",
        "#{SecurityWorkflow::RESCIND_NOTE}.",
      ].join("\n"),
      :update => lambda{|form| form.errata.change_state!('NEW_FILES', secalert_user)}
  end

  test 'multiple rescind reasons are combined in one comment' do
    e = rel_prep_approved_rhsa
    add_bug = Bug.find(698060)

    security_invalidate_test :errata => e,
      :user => secalert_user,
      :expected_comment => [
        "Product Security approval rescinded due to changed JIRA issues, changed bugs.\n",
        "#{SecurityWorkflow::RESCIND_NOTE}.",
      ].join("\n"),
      :update => lambda{|form|
        # two similar changes should not generate duplicate texts
        form.jira_issues.append('WFLY-326')
        form.jira_issues.remove('WFK2-139')
        form.bugs.append(add_bug.id)
      }
  end

  test 'docs approval required before requesting security approval' do
    e = rel_prep_rhba
    refute e.security_approved?
    assert e.docs_approved?
    e.disapprove_docs!
    refute e.can_request_security_approval?
    assert_equal 'Not requested, requires docs approval', e.security_approval_text
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

  def new_files_rhsa
    Errata.find(11149)
  end

  def qe_rhsa
    Errata.find(18894)
  end

  def block_errata!(e)
    BlockingIssue.create!(:summary => 'some summary',
      :description => 'some reason',
      :blocking_role => Role.find_by_name!('pm'),
      :who => secalert_user,
      :errata => e)
  end
end
