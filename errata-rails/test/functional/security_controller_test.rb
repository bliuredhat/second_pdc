require 'test_helper'

class SecurityControllerTest < ActionController::TestCase

  setup do
    auth_as secalert_user
  end

  test "form displays error if raised persisting a form object" do
    errata = RHSA.shipped_live.where(:text_only => 1).first
    Content.any_instance.expects(:text_only_cpe=).once
    Content.any_instance.expects(:save!).raises(err="kablooie")
    post :fix_cpe, :id => errata.id, :errata => { :cpe_text => @new_cpe }
    assert_response :success
    assert_equal "Errata Error occurred setting advisory CPE: #{err}", flash[:error]
  end

  test "request rcm push" do
    errata = RHSA.find(19028)
    assert_difference("Comment.count", 1) do
      assert_difference("ActionMailer::Base.deliveries.length", 2) do
        post :request_rcm_push, :id => errata.id
      end
    end
    assert_response :redirect
    assert_match /Requested RCM push/, flash[:notice]
    mail = ActionMailer::Base.deliveries.last(2).first
    assert_match /RHSA push request/, mail.subject
    ['release-engineering@redhat.com',
     errata.assigned_to.login_name,
     errata.reporter.login_name,
     errata.package_owner.login_name].each {|e| assert e.in?(mail.to) }
  end

  test "push xml to secalert" do
    test_push_xml RHSA.find(19435)
  end

  test "push xml for rhba" do
    test_push_xml RHBA.find(20044)
  end

  def test_push_xml(errata)
    assert_difference("Delayed::Job.count", 1) do
      post :push_xml_to_secalert, :id => errata.id
    end
    assert_response :redirect
    assert_equal 'Push XML job enqueued', flash[:notice]

    job = Delayed::Job.last
    Secalert::Xmlrpc.expects(:send_to_secalert).once
    job.invoke_job
  end

  # Note: This controller's functionality is also tested in:
  # - test/integration/fix_cpe_test.rb
  # - test/integration/fix_cve_test.rb
  # (so don't test things already covered there).

end
