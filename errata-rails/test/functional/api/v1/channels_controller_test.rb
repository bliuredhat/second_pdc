require 'test_helper'

class Api::V1::ChannelsControllerTest < ActionController::TestCase

  def channel_attributes
    {
      :name => 'test_channel',
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
    @api = 'api/v1/channels'
  end

  test "GET api/v1/channels returns 200 and all channels" do
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

  test "GET api/v1/channels/existing-id returns 200" do
    with_baselines(@api, /\/existing_(\d+).json$/) do |file, id|
      get :show, :format => :json, :id => id
      assert_response :success, response.body
      canonicalize_json(response.body)
    end
  end

  test "GET api/v1/channels/non-existing-id return 404" do
    with_baselines(@api, /\/non_existing_(\d+).json$/) do |file, id|
      get :show, :format => :json, :id => id
      assert_response :not_found, response.body
      canonicalize_json(response.body)
    end
  end

  test "error creating new channel without arch" do
    attrs = channel_attributes.except(:arch_name)
    with_baselines(@api, %r{\/create_no_arch.json$}) do
      post :create, :format => :json, :channel => attrs
      assert_response :unprocessable_entity, response.body
      canonicalize_json(response.body)
    end

    refute Channel.find_by_name(attrs[:name]).present?
  end

  test "error creating new channel without variant" do
    attrs = channel_attributes.except(:variant_name)
    with_baselines(@api, %r{\/create_no_variant.json$}) do
      post :create, :format => :json, :channel => attrs
      assert_response :unprocessable_entity, response.body
      canonicalize_json(response.body)
    end

    refute Channel.find_by_name(attrs[:name]).present?
  end

  test "error creating new channel with invalid attribute" do
    attrs = channel_attributes
    attrs[:bogo_attr] = 1
    with_baselines(@api, %r{\/create_invalid_attribute.json$}) do
      post :create, :format => :json, :channel => attrs
      assert_response :bad_request, response.body
      canonicalize_json(response.body)
    end

    refute Channel.find_by_name(attrs[:name]).present?
  end

  test "create new channel" do
    attrs = channel_attributes

    with_baselines(@api, %r{\/create.json$}) do |file, id|
      post :create, :format => :json, :channel => attrs
      assert_response :success, response.body
      canonicalize_json_ignore_id(response.body)
    end

    channel = Channel.find_by_name(attrs[:name])

    # Confirm that channel was created
    assert channel.present?

    # Get details of the newly created CDN repo
    with_baselines(@api, /\/newly_created.json$/) do |file, id|
      get :show, :format => :json, :id => channel.id
      assert_response :success, response.body
      canonicalize_json_ignore_id(response.body)
    end
  end

  test "create new channel with linked variant_names" do
    attrs = channel_attributes.merge({
      :variant_names => ['7Client-7.1.Z', '7Server-SA-7.1.Z']
    })
    attrs.delete(:variant_name)

    with_baselines(@api, %r{\/create_with_variant_names.json$}) do |file, id|
      post :create, :format => :json, :channel => attrs
      assert_response :success, response.body
      canonicalize_json_ignore_id(response.body)
    end

    # Confirm that channel was created
    assert Channel.find_by_name(attrs[:name])
  end

  test "update channel" do
    new_name = 'updated_channel_name'
    with_baselines(@api, %r{\/update.json$}) do |file, id|
      put :update,
        :format => :json,
        :id => 1,
        :channel => { :name => new_name }
      assert_response :success, response.body
      canonicalize_json(response.body)
    end

    # Check name has been updated
    assert_equal new_name, Channel.find(1).name
  end

  test "update channel with empty name error" do
    with_baselines(@api, %r{\/update_name_error.json$}) do |file, id|
      put :update,
        :format => :json,
        :id => 1,
        :channel => { :name => '' }
      assert_response :unprocessable_entity, response.body
      canonicalize_json(response.body)
    end
  end

  test "update channel with invalid variant error" do
    with_baselines(@api, %r{\/update_variant_error.json$}) do |file, id|
      put :update,
        :format => :json,
        :id => 1,
        :channel => { :variant_name => 'no_such_variant' }
      assert_response :not_found, response.body
      canonicalize_json(response.body)
    end
  end

  test "update channel with linked variant_ids" do
    new_name = 'updated_channel_name'
    assert_nil Channel.find_by_name(new_name)

    with_baselines(@api, %r{\/update_variant_ids.json$}) do |file, id|
      put :update,
        :format => :json,
        :id => 1,
        :channel => {
          :name => new_name,
          :variant_ids => [1023, 1038, 1198]
        }
      assert_response :success, response.body
      canonicalize_json(response.body)
    end

    # Check name has been updated
    assert_equal new_name, Channel.find(1).name
  end

  test "update channel with linked variant_names" do
    new_name = 'updated_channel_name'
    with_baselines(@api, %r{\/update_variant_names.json$}) do |file, id|
      put :update,
        :format => :json,
        :id => 1,
        :channel => {
          :name => new_name,
          :variant_names => ['7Client-7.1.Z', '7Server-SA-7.1.Z']
        }
      assert_response :success, response.body
      canonicalize_json(response.body)
    end

    # Check name has been updated
    assert_equal new_name, Channel.find(1).name
  end

  test "update channel with invalid variant_names" do
    with_baselines(@api, %r{\/update_bad_variant_names.json$}) do |file, id|
      put :update,
        :format => :json,
        :id => 1,
        :channel => {
          :variant_names => ['this_is_not_a_variant', 'neither_is_this']
        }
      assert_response :bad_request, response.body
      canonicalize_json(response.body)
    end
  end

  test "error creating channel with incompatible parameters" do
    attrs = channel_attributes.merge({
      :variant_id => 699,
      :variant_names => ['7Client-7.1.Z', '7Server-SA-7.1.Z']
    })

    with_baselines(@api, %r{\/create_with_incompatible_params.json$}) do
      post :create, :format => :json, :channel => attrs
      assert_response :bad_request, response.body
      canonicalize_json(response.body)
    end

    refute Channel.find_by_name(attrs[:name]).present?
  end

end
