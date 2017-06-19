require 'test_helper'

class Api::V1::CdnReposControllerTest < ActionController::TestCase

  def cdn_repo_attributes
    {
      :name => 'test_cdn_repo',
      :content_type => 'Binary',
      :release_type => 'FastTrack',
      :arch_name => 'x86_64',
      :variant_name => '7Client',
      :use_for_tps => false
    }
  end

  # Filter out id from response as it changes
  def canonicalize_json_ignore_id(body)
    canonicalize_json(body, :transform => lambda do |x|
      # Need to use strings, not symbols here
      assert x.key?('data')
      assert x['data'].has_key?('id')
      x['data'].delete('id')
      x
    end)
  end

  setup do
    auth_as admin_user
    @api = 'api/v1/cdn_repos'
  end

  test "GET api/v1/cdn_repos returns 200 and all cdn_repos" do
    with_baselines(@api, %r{\/index.json$}) do |file, id|
      get :index, :format => :json
      assert_response :success, response.body
      canonicalize_json(response.body)
    end
  end

  # test filter by attribute
  test "filter release_type" do
    with_baselines(@api, /\/release_type_(.+).json$/) do |file, release_type|
      get :index, :format => :json, :filter => { :release_type => release_type }
      assert_response :success, response.body
      canonicalize_json(response.body)
    end
  end

  test "filter arch_name" do
    with_baselines(@api, /\/arch_name_(.+).json$/) do |file, arch_name|
      get :index, :format => :json, :filter => { :arch_name => arch_name }
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

  test "filter content_type" do
    with_baselines(@api, /\/content_type_(.+).json$/) do |file, content_type|
      get :index, :format => :json, :filter => { :content_type => content_type }
      assert_response :success, response.body
      canonicalize_json(response.body)
    end
  end

  test "GET api/v1/cdn_repos/existing-id returns 200" do
    with_baselines(@api, /\/existing_(\d+).json$/) do |file, id|
      get :show, :format => :json, :id => id
      assert_response :success, response.body
      canonicalize_json(response.body)
    end
  end

  test "GET api/v1/cdn_repos/non-existing-id return 404" do
    with_baselines(@api, /\/non_existing_(\d+).json$/) do |file, id|
      get :show, :format => :json, :id => id
      assert_response :not_found, response.body
      canonicalize_json(response.body)
    end
  end

  test "error creating new cdn_repo without arch" do
    attrs = cdn_repo_attributes.except(:arch_name)
    with_baselines(@api, %r{\/create_no_arch.json$}) do
      post :create, :format => :json, :cdn_repo => attrs
      assert_response :unprocessable_entity, response.body
      canonicalize_json(response.body)
    end

    refute CdnRepo.find_by_name(attrs[:name]).present?
  end

  test "error creating new cdn_repo without variant" do
    attrs = cdn_repo_attributes.except(:variant_name)
    with_baselines(@api, %r{\/create_no_variant.json$}) do
      post :create, :format => :json, :cdn_repo => attrs
      assert_response :unprocessable_entity, response.body
      canonicalize_json(response.body)
    end

    refute CdnRepo.find_by_name(attrs[:name]).present?
  end

  test "error creating new cdn_repo with invalid attribute" do
    attrs = cdn_repo_attributes
    attrs[:bogo_attr] = 1
    with_baselines(@api, %r{\/create_invalid_attribute.json$}) do
      post :create, :format => :json, :cdn_repo => attrs
      assert_response :bad_request, response.body
      canonicalize_json(response.body)
    end

    refute CdnRepo.find_by_name(attrs[:name]).present?
  end

  test "create new cdn_repo" do
    attrs = cdn_repo_attributes

    with_baselines(@api, %r{\/create.json$}) do |file, id|
      post :create, :format => :json, :cdn_repo => attrs
      assert_response :success, response.body
      canonicalize_json_ignore_id(response.body)
    end

    cdn_repo = CdnRepo.find_by_name(attrs[:name])

    # Confirm that cdn_repo was created
    assert cdn_repo.present?

    # Get details of the newly created CDN repo
    with_baselines(@api, /\/newly_created.json$/) do |file, id|
      get :show, :format => :json, :id => cdn_repo.id
      assert_response :success, response.body
      canonicalize_json_ignore_id(response.body)
    end
  end

  test "create new cdn_repo with linked variant_names" do
    attrs = cdn_repo_attributes.merge({
      :variant_names => ['7Client-7.1.Z', '7Server-SA-7.1.Z']
    })
    attrs.delete(:variant_name)

    with_baselines(@api, %r{\/create_with_variant_names.json$}) do |file, id|
      post :create, :format => :json, :cdn_repo => attrs
      assert_response :success, response.body
      canonicalize_json_ignore_id(response.body)
    end

    # Confirm that cdn_repo was created
    assert CdnRepo.find_by_name(attrs[:name])
  end

  test "update cdn_repo" do
    new_name = 'updated_cdn_repo_name'
    with_baselines(@api, %r{\/update.json$}) do |file, id|
      put :update,
        :format => :json,
        :id => 1,
        :cdn_repo => { :name => new_name }
      assert_response :success, response.body
      canonicalize_json(response.body)
    end

    # Check name has been updated
    assert_equal new_name, CdnRepo.find(1).name
  end

  test "update cdn_repo with empty name error" do
    with_baselines(@api, %r{\/update_name_error.json$}) do |file, id|
      put :update,
        :format => :json,
        :id => 1,
        :cdn_repo => { :name => '' }
      assert_response :unprocessable_entity, response.body
      canonicalize_json(response.body)
    end
  end

  test "update cdn_repo with invalid variant error" do
    with_baselines(@api, %r{\/update_variant_error.json$}) do |file, id|
      put :update,
        :format => :json,
        :id => 1,
        :cdn_repo => { :variant_name => 'no_such_variant' }
      assert_response :not_found, response.body
      canonicalize_json(response.body)
    end
  end

  test "update package_ids" do
    assert_difference('CdnRepo.find(3001).packages.count', 1) do
      with_baselines(@api, %r{\/update_package_ids.json$}) do |file, id|
        put :update,
          :format => :json,
          :id => 3001,
          :cdn_repo => { :package_ids => [31610, 31611, 31616] }
        assert_response :success, response.body
        canonicalize_json(response.body)
      end
    end
  end

  test "update cdn_repo with linked variant_ids" do
    new_name = 'updated_cdn_repo_name'
    with_baselines(@api, %r{\/update_variant_ids.json$}) do |file, id|
      put :update,
        :format => :json,
        :id => 1,
        :cdn_repo => {
          :name => new_name,
          :variant_ids => [1023, 1038, 1198]
        }
      assert_response :success, response.body
      canonicalize_json(response.body)
    end

    # Check name has been updated
    assert_equal new_name, CdnRepo.find(1).name
  end

  test "update cdn_repo with linked variant_names" do
    new_name = 'updated_cdn_repo_name'
    with_baselines(@api, %r{\/update_variant_names.json$}) do |file, id|
      put :update,
        :format => :json,
        :id => 1,
        :cdn_repo => {
          :name => new_name,
          :variant_names => ['7Client-7.1.Z', '7Server-SA-7.1.Z']
        }
      assert_response :success, response.body
      canonicalize_json(response.body)
    end

    # Check name has been updated
    assert_equal new_name, CdnRepo.find(1).name
  end

  test "update cdn_repo with invalid variant_names" do
    with_baselines(@api, %r{\/update_bad_variant_names.json$}) do |file, id|
      put :update,
        :format => :json,
        :id => 1,
        :cdn_repo => {
          :variant_names => ['this_is_not_a_variant', 'neither_is_this']
        }
      assert_response :bad_request, response.body
      canonicalize_json(response.body)
    end
  end

  test "remove package_ids" do
    assert_difference('CdnRepo.find(3001).packages.count', -1) do
      with_baselines(@api, %r{\/remove_package_ids.json$}) do |file, id|
        put :update,
          :format => :json,
          :id => 3001,
          :cdn_repo => { :package_ids => [31610] }
        assert_response :success, response.body
        canonicalize_json(response.body)
      end
    end
  end

  test 'error updating locked packages' do
    Errata.find(21130).change_state!(State::IN_PUSH, admin_user)
    cdn_repo = CdnRepo.find(9999005)
    old_packages = cdn_repo.packages
    refute cdn_repo.cdn_repo_packages.first.can_destroy?
    assert_no_difference('CdnRepo.find(9999005).packages.count') do
      with_baselines(@api, %r{\/cdn_repo_package_locked.json$}) do |file, id|
        put :update,
          :format => :json,
          :id => cdn_repo.id,
          :cdn_repo => { :package_names => %w{rh-php56-docker rh-perl520-docker rh-ruby22-docker} }
        assert_response :bad_request, response.body
        canonicalize_json(response.body)
      end
    end
    assert_array_equal old_packages, cdn_repo.reload.packages
  end

  test "update package_names" do
    assert_difference('CdnRepo.find(3001).packages.count', 1) do
      with_baselines(@api, %r{\/update_package_names.json$}) do |file, id|
        put :update,
          :format => :json,
          :id => 3001,
          :cdn_repo => { :package_names => %w{rh-php56-docker rh-perl520-docker rh-ruby22-docker} }
        assert_response :success, response.body
        canonicalize_json(response.body)
      end
    end
  end

  test "update package_names with bad package name" do
    assert_difference('CdnRepo.find(3001).packages.count', 1) do
      with_baselines(@api, %r{\/update_package_bad_name.json$}) do |file, id|
        put :update,
          :format => :json,
          :id => 3001,
          :cdn_repo => { :package_names => %w{rh-php56-docker rh-perl520-docker bogo-package} }
        assert_response :success, response.body
        canonicalize_json(response.body, :transform => lambda do |x|
          # strip out package ids for consistency
          x['data']['relationships']['packages'].each{|p| p.delete('id')}
          x
        end)
      end
    end
  end

  test "error adding packages to unsupported repo type" do
    cdn_repo = CdnBinaryRepo.last
    assert cdn_repo.packages.empty?
    with_baselines(@api, %r{\/packages_unsupported_type.json$}) do |file, id|
      put :update,
        :format => :json,
        :id => cdn_repo.id,
        :cdn_repo => { :package_names => %w{rh-php56-docker} }
      assert_response :unprocessable_entity, response.body
      canonicalize_json(response.body)
    end

    # Package count should be unchanged
    assert cdn_repo.reload.packages.empty?
  end

  test "error creating new unsupported cdn_repo with packages" do
    attrs = cdn_repo_attributes
    attrs[:package_names] = %w{rh-php56-docker}
    with_baselines(@api, %r{\/create_with_packages_unsupported.json$}) do
      post :create, :format => :json, :cdn_repo => attrs
      assert_response :unprocessable_entity, response.body
      canonicalize_json(response.body)
    end

    refute CdnRepo.find_by_name(attrs[:name]).present?
  end

  test "creating new docker repo with packages" do
    attrs = cdn_repo_attributes
    attrs[:package_names] = %w{rh-php56-docker}
    attrs[:content_type] = 'Docker'
    with_baselines(@api, %r{\/create_with_packages.json$}) do
      post :create, :format => :json, :cdn_repo => attrs
      assert_response :success, response.body
      canonicalize_json_ignore_id(response.body)
    end

    assert CdnRepo.find_by_name(attrs[:name]).present?
  end

  test "error creating cdn_repo with incompatible parameters" do
    attrs = cdn_repo_attributes.merge({
      :variant_id => 699,
      :variant_names => ['7Client-7.1.Z', '7Server-SA-7.1.Z']
    })

    with_baselines(@api, %r{\/create_with_incompatible_params.json$}) do
      post :create, :format => :json, :cdn_repo => attrs
      assert_response :bad_request, response.body
      canonicalize_json(response.body)
    end

    refute CdnRepo.find_by_name(attrs[:name]).present?
  end

end
