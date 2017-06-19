require 'test_helper'

class Api::V1::ReleasesControllerTest < ActionController::TestCase

  setup do
    auth_as admin_user
    @api = 'api/v1/releases'
  end

  test "GET #{@api} returns 200 and all releases" do
    with_baselines(@api, %r{\/index.json$}) do |file, id|
      get :index, :format => :json
      assert_response :success, response.body
      canonicalize_json(response.body)
    end
  end

  # test filter by attribute
  test "GET #{@api}?filter[active]=true returns active releases" do
    ['true', '1', true, 1].each do | active |
      with_baselines('api/v1/releases/', %r{\/find_all_active.json$}) do |*|
        get :index, :format => :json, :filter => { :is_active => active }
        assert_response :success, response.body
        canonicalize_json(response.body)
      end
    end
  end

  test "GET #{@api}?filter[is_active]=true&filter[enabled] returns releases" do
    ['true', '1', true, 1].each do | yes |
      with_baselines('api/v1/releases/', %r{\/find_active_and_enabled.json$}) do |*|
        get :index, :format => :json,
            :filter => { :is_active => yes, :enabled => yes }
        assert_response :success, response.body
        canonicalize_json(response.body)
      end
    end
  end

  test "GET #{@api}?filter[blocked_flags] returns 400" do
    with_baselines(@api, %r{\/find_unsupported_attrs.json$}) do |*|
      get :index, :format => :json, :filter => { :blocker_flags => [] }
      assert_response :bad_request, response.body
      canonicalize_json(response.body)
    end
  end

  test "GET #{@api}?filter[foo]=bar returns 400" do
    with_baselines(@api, %r{\/find_invalid_attrs.json$}) do |*|
      get :index, :format => :json, :filter => { :foo => :bar }
      assert_response :bad_request, response.body
      canonicalize_json(response.body)
    end
  end

  test "GET #{@api}/existing-id returns 200" do
    with_baselines(@api, /\/existing_(\d+).json$/) do |file, id|
      get :show, :format => :json, :id => id
      assert_response :success, response.body
      canonicalize_json(response.body)
    end
  end

  test "GET #{@api}/non-existing-id return 404" do
    with_baselines(@api, /\/non_existing_(\d+).json$/) do |file, id|
      get :show, :format => :json, :id => id
      assert_response :not_found, response.body
      canonicalize_json(response.body)
    end
  end

end
