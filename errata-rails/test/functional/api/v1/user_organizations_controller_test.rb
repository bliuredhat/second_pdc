require 'test_helper'

class Api::V1::UserOrganizationsControllerTest < ActionController::TestCase
  test "test search group" do
    auth_as admin_user

    get :search, :name => 'Internationalization', :format => :json
    assert_response :ok, response.body
    assert_testdata_equal "api/v1/user_organizations/search.json", formatted_json_response
  end
end
