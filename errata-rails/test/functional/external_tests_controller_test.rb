require 'test_helper'

class ExternalTestsControllerTest < ActionController::TestCase

  setup do
    test_type = 'covscan'
    rhba_async.state_machine_rule_set.test_requirements << test_type
    rhba_async.state_machine_rule_set.save!
    @test_run = rhba_async.create_external_test_run_for(:covscan, :external_id => 123)
    @referer = 'http://test.com/ext_tests/1'
    @request.env['HTTP_REFERER'] = @referer
  end

  test "test data is in the right state" do
    assert_equal 'PENDING', @test_run.status
  end

  test "updates test run successfully" do
    expected_state = 'OK'
    auth_as releng_user

    XMLRPC::CovscanClient.any_instance.expects(:get_scan_state).returns(
      {'status' => 'OK', 'state' => expected_state})

    post :refresh_test_run_status, :test_run_id => @test_run
    assert_redirected_to @referer
    @test_run.reload
    assert_equal expected_state, @test_run.status
  end

  test "update test run propagates error successfully" do
    auth_as qa_user

    XMLRPC::CovscanClient.any_instance.expects(:get_scan_state).returns(
      {'status' => 'ZONK'})

    post :refresh_test_run_status, :test_run_id => @test_run
    assert_response :redirect
    assert_match %r{Error occurred}, flash[:error]
  end

  test "will not show refresh status link if not supported" do
    auth_as qa_user
    ExternalTestRun.any_instance.expects(:can_update_status?).returns(false)

    post :list, :id => @test_run.errata, :test_run_id => @test_run, :test_type => :covscan
    assert_response :success
    assert_no_match %r{Refresh status}, response.body
    assert_match %r{\bView in Covscan\b}, response.body
  end

  #
  # This is for the possiblity of other external tests than covscan who
  # might not be refreshable.
  #
  test "error when refreshing unsupported external tests" do
    auth_as qa_user
    ExternalTestRun.any_instance.expects(:can_update_status?).returns(false)

    post :refresh_test_run_status, :test_run_id => @test_run
    assert_response :redirect
    assert flash[:error].present?
  end

  test "redirect when trying to reschedule tests with POST" do
    auth_as qa_user

    get :reschedule, :test_run_id => @test_run
    assert_response :redirect
    assert_redirected_to :action => :list_all
  end

  test "Show alert if rescheduling is not permitted" do
    auth_as qa_user

    test_run = ExternalTestRun.find(41)
    type = ExternalTestType.create!(
      :name          => 'foo/bar',
      :display_name  => 'Foo Scan (bar)',
      :prod_run_url  => 'http://foo.redhat.com/scan/$ID/',
      :test_run_url  => 'http://foo-test.redhat.com/scan/$ID/',
      :info_url      => 'https://engineering.redhat.com/trac/AboutFoo/wiki')
    refute type.reschedule_supported?
    test_run.external_test_type = type
    test_run.save!

    MessageBus.expects(:send_message).never

    post :reschedule, :test_run_id => test_run
    assert_response :redirect
    assert flash[:alert].present?
    assert_match %r{\bScan.*not rescheduled!$}, flash[:alert]
  end

end
