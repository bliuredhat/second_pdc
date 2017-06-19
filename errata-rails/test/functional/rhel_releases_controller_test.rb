require 'test_helper'

class RhelReleasesControllerTest < ActionController::TestCase

  test "create new rhel version" do
    auth_as admin_user

    data = {
        :rhel_release => {
          :exclude_ftp_debuginfo => "0",
          :name                  => "",
          :description           => "",
      }
    }

    assert_no_difference('RhelRelease.count') do
      post :create, data
      assert_response :success
      refute assigns(:rhel_release).errors.empty?
    end

    data[:rhel_release].update(:name => "Test Release", :description => "Foobar")

    assert_difference('RhelRelease.count') do
      post :create, data

      assert_response :redirect
      assert assigns(:rhel_release).errors.empty?
    end
  end

  test "index" do
    auth_as admin_user

    get :index, :format => :json

    assert_response :success
    response_data = ActiveSupport::JSON.decode(response.body)
    response_data.each do |content|
      assert content.has_key?('rhel_release')
      %w[id name description exclude_ftp_debuginfo].each do |field|
        assert content['rhel_release'].has_key?(field), "Expected '#{field}' to be present in JSON response"
      end
    end
  end

  test "rhel release json contains expected fields" do
    auth_as admin_user

    get :show, :id => 1, :format => :json

    assert_response :success
    response_data = ActiveSupport::JSON.decode(response.body)
    assert response_data.has_key?('rhel_release')
    %w[id name description exclude_ftp_debuginfo].each do |field|
      assert response_data['rhel_release'].has_key?(field), "Expected '#{field}' to be present in JSON response"
    end
  end

end
