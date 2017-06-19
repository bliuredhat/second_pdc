require 'test_helper'

class Api::V1::CdnRepoPackageTagsControllerTest < ActionController::TestCase

  # Filter out id from response as it changes
  def canonicalize_json_ignore_id(body)
    canonicalize_json(body, :transform => lambda do |x|
      # Need to use strings, not symbols here
      assert x.has_key?('data')
      assert x['data'].has_key?('id')
      x['data'].delete('id')
      x
    end)
  end

  setup do
    auth_as admin_user
    @api = 'api/v1/cdn_repo_package_tags'
  end

  test "GET api/v1/cdn_repo_package_tags returns 200 and all cdn_repo_package_tags" do
    with_baselines(@api, %r{\/index.json$}) do |file, id|
      get :index, :format => :json
      assert_response :success, response.body
      canonicalize_json(response.body)
    end
  end

  # test filter by attribute
  test "filter tag_template" do
    with_baselines(@api, /\/tag_template_(.+).json$/) do |file, tag_template|
      get :index, :format => :json, :filter => { :tag_template => tag_template }
      assert_response :success, response.body
      canonicalize_json(response.body)
    end
  end

  test "filter package_name" do
    with_baselines(@api, /\/package_name_(.+).json$/) do |file, package_name|
      get :index, :format => :json, :filter => { :package_name => package_name }
      assert_response :success, response.body
      canonicalize_json(response.body)
    end
  end

  test "filter cdn_repo_id" do
    with_baselines(@api, /\/cdn_repo_id_(.+).json$/) do |file, cdn_repo_id|
      get :index, :format => :json, :filter => { :cdn_repo_id=> cdn_repo_id }
      assert_response :success, response.body
      canonicalize_json(response.body)
    end
  end

  test "filter variant_name" do
    with_baselines(@api, /\/variant_name_(.+).json$/) do |file, variant_name|
      get :index, :format => :json, :filter => { :variant_name => variant_name }
      assert_response :success, response.body
      canonicalize_json(response.body)
    end
  end

  test "GET api/v1/cdn_repo_package_tags/existing-id returns 200" do
    with_baselines(@api, /\/existing_(\d+).json$/) do |file, id|
      get :show, :format => :json, :id => id
      assert_response :success, response.body
      canonicalize_json(response.body)
    end
  end

  test "GET api/v1/cdn_repo_package_tags/non-existing-id return 404" do
    with_baselines(@api, /\/non_existing_(\d+).json$/) do |file, id|
      get :show, :format => :json, :id => id
      assert_response :not_found, response.body
      canonicalize_json(response.body)
    end
  end

  test "DELETE api/v1/cdn_repo_package_tags/existing-id deletes tag" do
    assert_difference('CdnRepoPackageTag.count', -1) do
      delete :destroy, :format => :json, :id => 1
      assert_response :no_content, response.body
      assert_blank response.body
    end
  end

  test "error creating new cdn_repo_package_tag without package" do
    assert_no_difference('CdnRepoPackageTag.count') do
      with_baselines(@api, %r{\/create_no_package.json$}) do
        post :create, :format => :json,
          :cdn_repo_package_tag => { :cdn_repo_id => 3001, :tag_template => '__test__' }
        assert_response :bad_request, response.body
        canonicalize_json(response.body)
      end
    end
  end

  test "error creating new cdn_repo_package_tag without cdn_repo" do
    assert_no_difference('CdnRepoPackageTag.count') do
      with_baselines(@api, %r{\/create_no_cdn_repo.json$}) do
        post :create, :format => :json,
          :cdn_repo_package_tag => { :package_name => 'rh-perl520-docker', :tag_template => '__test__' }
        assert_response :bad_request, response.body
        canonicalize_json(response.body)
      end
    end
  end

  test "error creating new tag for unmapped package" do
    assert_no_difference('CdnRepoPackageTag.count') do
      with_baselines(@api, %r{\/unmapped_package.json$}) do
        post :create, :format => :json,
          :cdn_repo_package_tag => { :package_id => 1, :cdn_repo_id => 3001, :tag_template => '__test__' }
        assert_response :bad_request, response.body
        canonicalize_json(response.body)
      end
    end
  end

  test "error creating new cdn_repo_package_tag with invalid attribute" do
    assert_no_difference('CdnRepoPackageTag.count') do
      with_baselines(@api, %r{\/create_invalid_attribute.json$}) do
        post :create, :format => :json,
          :cdn_repo_package_tag => { :cdn_repo_package_id => 1, :tag_template => '__test__', :bogo_attr => 1 }
        assert_response :bad_request, response.body
        canonicalize_json(response.body)
      end
    end
  end

  test "create new cdn_repo_package_tag" do
    assert_difference('CdnRepoPackageTag.count', 1) do
      with_baselines(@api, %r{\/create.json$}) do |file, id|
        post :create, :format => :json,
          :cdn_repo_package_tag => { :cdn_repo_package_id => 1, :tag_template => '__test__' }
        assert_response :success, response.body
        canonicalize_json_ignore_id(response.body)
      end
    end
  end

  test "create new cdn_repo_package_tag with variant" do
    assert_difference('CdnRepoPackageTag.count', 1) do
      with_baselines(@api, %r{\/create_with_variant.json$}) do |file, id|
        post :create, :format => :json,
          :cdn_repo_package_tag => { :cdn_repo_package_id => 1, :tag_template => '__test__', :variant_name => '7Server' }
        assert_response :success, response.body
        canonicalize_json_ignore_id(response.body)
      end
    end
  end

  test "update cdn_repo_package_tag" do
    new_tag_template = '__updated_tag_template__'
    with_baselines(@api, %r{\/update.json$}) do |file, id|
      put :update,
        :format => :json,
        :id => 1,
        :cdn_repo_package_tag => { :tag_template => new_tag_template, :variant_name => '7Server' }
      assert_response :success, response.body
      canonicalize_json(response.body)
    end

    # Check tag_template has been updated
    assert_equal new_tag_template, CdnRepoPackageTag.find(1).tag_template
  end

end
