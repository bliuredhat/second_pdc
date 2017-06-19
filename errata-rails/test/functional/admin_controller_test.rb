require 'test_helper'

class AdminControllerTest < ActionController::TestCase

  test "index access" do
    [admin_user, releng_user, secalert_user, pm_user, devel_user, qa_user].each do |user|
      auth_as user
      get :index
      assert_response :success
      assert_template 'index'
    end
  end

end
