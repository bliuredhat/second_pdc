require 'test_helper'

class CommentsTest < ActionDispatch::IntegrationTest

  setup do
    auth_as releng_user
    @api = 'api/v1/comments'
  end

  test "queries for comments successfully" do
    with_baselines(@api, /index.json$/) do |match|
      get @api
      assert_response :success, response.body
      canonicalize_json(response.body)
    end
  end
end
