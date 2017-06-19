require 'test_helper'

class Api::V1::CommentsControllerTest < ActionController::TestCase


  setup do
    auth_as devel_user
    @api = 'api/v1/comments'
  end

  test "GET #{API}?filter['errata_id']=11112 returns 200" do
    with_baselines(@api, %r{\/index_filter_for_advisory_11112.json$}) do |*|
      get :index, :filter => {:errata_id => RHEA.find(11112)}, :format => :json
      assert_response :success, response.body
      canonicalize_json(response.body)
    end
  end

  test "GET @#{API} filter by advisory and comment type returns 200" do
    with_baselines(@api, %r{\/index_filter_for_comment_type_advisory_11112.json$}) do |*|
      get :index, :filter => {:type => AutomatedComment.name,
                              :errata_id => RHEA.find(11112)}, :format => :json
      assert_response :success, response.body
      canonicalize_json(response.body)
    end
  end

  test "GET #{API}/745780 returns 200" do
    with_baselines(@api, %r{\/show_745780.json$}) do |*|
      get :show, :id => 745780, :format => :json
      assert_response :success, response.body
      canonicalize_json(response.body)
    end
  end
end
