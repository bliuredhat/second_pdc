require 'test_helper'

class Api::V1::ArchesControllerTest < ActionController::TestCase

  setup do
    auth_as admin_user
    @api = 'api/v1/arches'
  end

  # test index action
  test "GET #{@api} returns 200 and all arches" do
    with_baselines(@api, %r{\/index.json$}) do |*|
      get :index, :format => :json
      assert_response :success, response.body
      canonicalize_json(response.body)
    end
  end

  # test filter by attribute
  test "GET #{@api}?filter[active]=true returns active arches" do
    ['true', '1', true, 1].each do | active |
      with_baselines(@api, %r{\/find_all_active.json$}) do |*|
        get :index, :format => :json, :filter => { :active => active }
        assert_response :success, response.body
        canonicalize_json(response.body)
      end
    end
  end

  test "GET #{@api}?filter[id]=non_existing returns 200 and empty data" do
    with_baselines( @api, %r{\/find_non_existing_arch_combo.json$}) do |_, id|
      get :index, :format => :json, :filter => { :id => id }
      assert_response :success, response.body
      canonicalize_json(response.body)
    end
  end

  test "GET #{@api}?filter[name]=amd64 returns 200 and an arch" do
    with_baselines(@api, %r{\/find_by_name.json$}) do |*|
      get :index, :format => :json, :filter => { :name => 'amd64' }
      assert_response :success, response.body
      canonicalize_json(response.body)
    end
  end

  test "GET #{@api}?filter[x]=a&filter[y]=b returns 200 and expected data" do
    # test if the two filters that if executed in isolation returns arches do
    # not return anything when applied together. So there are active arches and
    # there is an arch with name: amd64. But amd64 is inactive so when
    # filtered by active = true and name = amd64 it shouldn't return any arch

    with_baselines(@api, %r{\/find_non_existing_arch_combo.json$}) do |*|

      get :index, :format => :json,
          :filter => {
            :active => 'true',
            :name => 'amd64'
          }
      assert_response :success, response.body
      canonicalize_json(response.body)
    end

    # now do the same but active = false
    with_baselines(@api, %r{\/find_inactive_amd64.json$}) do |*|
      get :index, :format => :json,
          :filter => {
            :active => 'false',
            :name => 'amd64'
          }
      assert_response :success, response.body
      canonicalize_json(response.body)
    end
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
