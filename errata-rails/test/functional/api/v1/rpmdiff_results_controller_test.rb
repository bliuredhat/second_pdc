require 'test_helper'

class Api::V1::RpmdiffResultsControllerTest < ActionController::TestCase

  setup do
    auth_as devel_user
    @api = 'api/v1/rpmdiff_results'
  end

  # test show action
  test "GET #{@api}/existing-id returns 200" do
    with_baselines(@api, /\/existing_(\d+).json$/) do |_, id|
      get :show, :format => :json, :id => id
      assert_response :success, response.body
      canonicalize_json(response.body)
    end
  end

  test "GET #{@api}/non-existing-id return 404" do
    with_baselines(@api, /\/non_existing_(\d+).json$/) do |_, id|
      get :show, :format => :json, :id => id
      assert_response :not_found, response.body
      canonicalize_json(response.body)
    end
  end

end
