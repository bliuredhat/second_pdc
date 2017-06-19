require 'test_helper'

class Api::V1::StateIndicesControllerTest < ActionController::TestCase
  setup do
    auth_as devel_user
    @api = 'api/v1/state_indices'
  end

  test "GET #{API}/10844 returns 200" do
    with_baselines(@api, %r{\/show_advisory_10844.json$}) do |*|
      get :show, :id => 10844, :format => :json
      assert_response :success, response.body
      canonicalize_json(response.body)
    end
  end
end
