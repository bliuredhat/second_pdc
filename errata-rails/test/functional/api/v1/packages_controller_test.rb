require 'test_helper'

class Api::V1::PackagesControllerTest < ActionController::TestCase

  API = 'api/v1/packages'

  setup do
    auth_as admin_user
  end

  test "GET #{API} returns 400 as all packages list is not allowed" do
    with_baselines(API, %r{\/index.json$}) do |*|
      get :index, :format => :json
      assert_response :bad_request, response.body
      canonicalize_json(response.body)
    end
  end

  # test filter by attribute
  test "GET #{API}?filter[name]=nss returns package with name nss" do
    %w(nss libvirt libcgroup).each do |name|
      with_baselines(API, Regexp.new("find_name_#{name}.json$")) do |*|
        get :index, :format => :json, :filter => { :name => name }
        assert_response :success, response.body
        canonicalize_json(response.body)
      end
    end
  end

  test "GET #{API}?filter[name]=non_existing returns empty data" do
    with_baselines(API, %r{\/find_name_non_existing.json$}) do |*|
      get :index, :format => :json, :filter => { :name => 'foobar' }
      assert_response :success, response.body
      canonicalize_json(response.body)
    end
  end

  test "GET #{API}?filter[foo]=bar returns 400 as foo is an invalid attribute" do
    with_baselines(API, %r{\/find_invalid_attrs.json$}) do |*|
      get :index, :format => :json, :filter => { :foo => :bar }
      assert_response :bad_request, response.body
      canonicalize_json(response.body)
    end
  end

  test "GET #{API}/existing-id returns 200" do
    with_baselines(API, %r{\/existing_(\d+).json$}) do |_, id|
      get :show, :format => :json, :id => id
      assert_response :success, response.body
      canonicalize_json(response.body)
    end
  end

  test "GET #{API}/non-existing-id return 404" do
    with_baselines(API, %r{\/non_existing_(\d+).json$}) do |_, id|
      get :show, :format => :json, :id => id
      assert_response :not_found, response.body
      canonicalize_json(response.body)
    end
  end

end
