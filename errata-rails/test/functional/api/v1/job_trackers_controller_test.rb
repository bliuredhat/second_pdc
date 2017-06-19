require 'test_helper'

class Api::V1::JobTrackersControllerTest < ActionController::TestCase

  setup do
    auth_as admin_user
  end

  test 'baseline test' do
    with_baselines('api/v1/job_trackers', %r{/show_(.+)\.json$}) do |file,id|
      get :show, :id => id, :format => :json
      assert_response :success, response.body
      canonicalize_json(response.body)
    end
  end

  test "job tracker gives 404 OK" do
    get :show,
      :format => :json,
      :id => 999999
    assert_response :not_found
  end

end


