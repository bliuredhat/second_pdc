require 'test_helper'

class DocsControllerTest < ActionController::TestCase

  test 'individual advisory docs views' do
    #
    # Note: This test is slow, memory intensive, and not very cost-effective in
    # terms of how long it takes. (I like to keep it anyway, but perhaps we could
    # disable it via an environment var for speedy test mode).
    #
    auth_as docs_user

    VCR.use_cassette 'all_pdc_advisories' do
      Errata.all.each do |errata|
        errata_id = errata.id

        [:show, :diff_history, :doc_text_info, :draft_release_notes_text, :draft_release_notes_xml].each do |action|
          get action, :id => errata_id
          assert_response :success, "/#{action}/#{errata_id}: #{@response.body}"
        end

      end
    end
  end

  test 'show bugs only' do
    auth_as docs_user
    fb = FiledBug.first
    get :show, :id => fb.errata.id, :nolayout => true
    assert_response :success
    assert_match /3\. Bug IDs fixed:/, response.body, response.body
    assert_match /\b#{fb.bug.id}\b/, response.body, response.body
    assert_no_match /JIRA Issues fixed:/, response.body, response.body
  end

  test 'show jira issues only' do
    auth_as docs_user
    fji = FiledJiraIssue.first
    get :show, :id => fji.errata.id, :nolayout => true
    assert_response :success
    assert_match /3\. JIRA Issues fixed:/, response.body, response.body
    assert_match /\b#{fji.jira_issue.key}\b/, response.body, response.body
    assert_no_match /Bug IDs fixed:/, response.body, response.body
  end

  test 'show bugs and jira issues' do
    auth_as docs_user
    e = Errata.where(:id => FiledJiraIssue.select(:errata_id)).where(:id => FiledBug.select(:errata_id)).first
    get :show, :id => e.id, :nolayout => true
    assert_response :success
    assert_match /3\. Bug IDs fixed:/, response.body, response.body
    assert_match /4\. JIRA Issues fixed:/, response.body, response.body
    assert_match /\b#{e.bugs.first.id}\b/, response.body, response.body
    assert_match /\b#{e.jira_issues.first.key}\b/, response.body, response.body
  end

  test 'baseline test for some advisory docs content' do
    auth_as devel_user
    VCR.use_cassettes_for(:pdc_ceph21) do
      with_baselines('docs_baseline', /errata-(\d+)\.html/) do |file, id|
        get :show, :id => id, :nolayout => true
        assert_response :success, response.body
        response.body
      end
    end
  end

  #
  # See bug 990048
  #
  def do_approval_permission_check(user, should_be_permitted)
    VCR.use_cassette 'get pdc content delivery repos' do
      @in_queue = Errata.in_docs_queue.last
      @approved = Errata.where_docs_approved.last
      refute @in_queue.docs_approved?
      assert @approved.docs_approved?

      auth_as user

      # Button visibility
      get :show, :id => @in_queue.id
      assert_response :success
      if should_be_permitted
        assert_select "a.btn", { :text => 'Approve Docs',    :count => 1 }, "should see approve docs button"
        assert_select "a.btn", { :text => 'Disapprove Docs', :count => 1 }, "should see disapprove docs button"
      else
        assert_select "a.btn", { :text => 'Approve Docs',    :count => 0 }, "should not see approve docs button"
        assert_select "a.btn", { :text => 'Disapprove Docs', :count => 0 }, "should not see disapprove docs button"
      end

      # Approve
      post :approve, :id => @in_queue.id, :back_to => 'show'
      assert_redirected_to :action => :show, :id => @in_queue.id
      if should_be_permitted
        assert_match(/ APPROVED/, flash[:notice])
        assert_nil flash[:error]
        assert @in_queue.reload.docs_approved?

        comment = @in_queue.comments.last
        assert comment.is_a?(DocsApprovalComment)
        assert_match(/ APPROVED/, comment.text)

        mail = ActionMailer::Base.deliveries.last
        assert_equal 'DOCUMENTATION', mail['X-ErrataTool-Component'].value
        assert_equal 'APPROVED', mail['X-ErrataTool-Action'].value
      else
        assert_match(/not permitted to approve/, flash[:error])
        assert_nil flash[:notice]
        refute @in_queue.reload.docs_approved?
      end

      # Disapprove
      post :disapprove, :id => @approved.id, :back_to => 'show'
      assert_redirected_to :action => :show, :id => @approved.id
      if should_be_permitted
        assert_match(/ DISAPPROVED/, flash[:notice])
        assert_nil flash[:error]
        refute @approved.reload.docs_approved?

        comment = @approved.comments.last
        assert comment.is_a?(DocsApprovalComment)
        assert_match(/ DISAPPROVED/, comment.text)

        mail = ActionMailer::Base.deliveries.last
        assert_equal 'DOCUMENTATION', mail['X-ErrataTool-Component'].value
        assert_equal 'DISAPPROVED', mail['X-ErrataTool-Action'].value
      else
        assert_match(/not permitted to disapprove/, flash[:error])
        assert_nil flash[:notice]
        assert @approved.reload.docs_approved?
      end
    end
  end

  test 'docs user can approve docs' do
    do_approval_permission_check(docs_user, true)
  end

  test 'qe user can not approve docs' do
    do_approval_permission_check(qa_user, false)
  end

  test 'devel user can not approve docs' do
    do_approval_permission_check(devel_user, false)
  end

  test "change docs reviewer with xhr call" do
    auth_as devel_user

    xhr :post, :change_docs_reviewer,
        :id => rhba_async.id,
        :user_id => User.last.id
    assert_response :success
  end

  test "change docs reviewer" do
    auth_as devel_user

    post :change_docs_reviewer,
         :id => rhba_async.id,
         :user_id => rhba_async.content.doc_reviewer.id
    assert_redirected_to :controller=>:errata, :action=>:view, :id=>rhba_async
    assert_not_nil flash[:alert]
  end

end
