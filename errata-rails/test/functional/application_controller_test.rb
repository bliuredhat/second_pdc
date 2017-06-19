require 'test_helper'

class ApplicationControllerTest < ActionController::TestCase

  setup do
    @qe_advisory = Errata.find(11110)
    @controller.instance_variable_set(:@errata, @qe_advisory)
  end

  test "navigation includes distqa_results after successful staging push" do
    @qe_advisory.stubs(:has_distqa_jobs?).returns(true)

    result = @controller.send(:get_individual_errata_nav)
    assert result.map { |j| j[:action] }.include? 'rhnqa_results'
  end

  test "navigation excludes distqa results without staging push" do
    @qe_advisory.stubs(:has_distqa_jobs?).returns(false)

    result = @controller.send(:get_individual_errata_nav)
    refute result.map { |j| j[:action] }.include? 'rhnqa_results'
  end

end

class SomeTestsController < ApplicationController
  before_filter :find_by_id_or_name, :only => [:index]
  def index
    render :text => "hello world!", :status => :ok
  end

  def error
    redirect_to_error! 'a problem occurred', :bad_request
  end
end

class SomeTest
  def initialize
    @some_value = "foo"
  end

  def self.find(value)
    self.new
  end
end

class SomeTestsControllerTest < ActionController::TestCase
  setup do
    @controller.logger = MockLogger
  end

  test "find_by_id_or_name without id or name param should fail" do
    auth_as admin_user

    post :index
    assert_response :not_found
    assert_equal "find_by_id_or_name No id or name parameter given", MockLogger.log.last
  end

  test "find_by_id_or_name with invalid model field should fail" do
    auth_as admin_user

    post :index, {:name => "something" }
    assert_response :not_found
    assert_equal "find_by_id_or_name SomeTest does not respond to find_by_name!", MockLogger.log.last
  end

  test "find_by_id_or_name with invalid model class should fail" do
    auth_as admin_user
    Kernel.stubs(:const_get).raises(RuntimeError)

    post :index, {:id => 12345}
    assert_response :not_found
    assert_equal "find_by_id_or_name No such class name SomeTest", MockLogger.log.last
  end

  test "find_by_id_or_name with valid param" do
    auth_as admin_user

    post :index, {:id => 12345}
    assert !@controller.instance_variable_get('@some_test').nil?
    assert_response :success
  end

  test "ensure security headers are present" do
    auth_as admin_user

    post :index, {:id => 12345}
    assert @response.headers.has_key?('X-Content-Type-Options')
    assert @response.headers.has_key?('X-Frame-Options')
    assert @response.headers.has_key?('X-XSS-Protection')
    assert_response :success
  end

  test "ensure HSTS enabled with HTTPS" do
    auth_as admin_user

    request.env['HTTPS'] = 'on'
    post :index, {:id => 12345}
    assert @response.headers.has_key?('Strict-Transport-Security')
    assert_response :success
  end

  test 'errors are returned as JSON when JS requested' do
    auth_as admin_user
    get :error, :format => :js
    body = response.body
    object = JSON.parse(body)
    assert_equal({'error' => 'a problem occurred'}, object)
  end
end
