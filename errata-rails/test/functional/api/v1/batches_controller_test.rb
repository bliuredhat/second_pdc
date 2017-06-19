require 'test_helper'

class Api::V1::BatchesControllerTest < ActionController::TestCase

  setup do
    auth_as admin_user
    @api = 'api/v1/batches'
  end

  test "GET api/v1/batches returns 200 and all batches" do
    with_baselines(@api, %r{\/index.json$}) do |file, id|
      get :index, :format => :json
      assert_response :success, response.body
      canonicalize_json(response.body)
    end
  end

  # test filter by attribute
  test "GET api/v1/batches?filter[is_active]=true returns active batches" do
    ['true', '1', true, 1].each do | active |
      with_baselines(@api, %r{\/find_all_active.json$}) do |*|
        get :index, :format => :json, :filter => { :is_active => active }
        assert_response :success, response.body
        canonicalize_json(response.body)
      end
    end
  end

  test "GET api/v1/batches?filter[is_active]=false returns inactive batches" do
    ['false', '0', false, 0].each do | active |
      with_baselines(@api, %r{\/find_all_inactive.json$}) do |*|
        get :index, :format => :json, :filter => { :is_active => active }
        assert_response :success, response.body
        canonicalize_json(response.body)
      end
    end
  end

  test "GET api/v1/batches?filter[description]=false returns correct batch" do
    with_baselines(@api, %r{\/find_false_description.json$}) do |*|
      get :index, :format => :json, :filter => { :description => 'false' }
      assert_response :success, response.body
      canonicalize_json(response.body)
    end
  end

  test "GET api/v1/batches/existing-id returns 200" do
    with_baselines(@api, /\/existing_(\d+).json$/) do |file, id|
      get :show, :format => :json, :id => id
      assert_response :success, response.body
      canonicalize_json(response.body)
    end
  end

  test "GET api/v1/batches/non-existing-id return 404" do
    with_baselines(@api, /\/non_existing_(\d+).json$/) do |file, id|
      get :show, :format => :json, :id => id
      assert_response :not_found, response.body
      canonicalize_json(response.body)
    end
  end

  test "create new batch without release" do
    batch_name = 'test_batch'
    with_baselines(@api, %r{\/create_no_release.json$}) do |file, id|
      post :create,
        :format => :json,
        :name => batch_name
      assert_response :unprocessable_entity, response.body
      canonicalize_json(response.body)
    end

    refute Batch.find_by_name(batch_name).present?
  end

  test "create new batch" do
    batch_name = 'test_batch'
    release_id = 452
    release_date = '2015-09-30'

    with_baselines(@api, %r{\/create.json$}) do |file, id|

      # Filter out id from response as it changes
      filter_out_id = lambda do |x|
        # Need to use strings, not symbols here
        assert x.key?('data')
        assert x['data'].has_key?('id')
        x['data'].delete('id')
        x
      end

      post :create,
        :format => :json,
        :name => batch_name,
        :release_id => release_id,
        :release_date => release_date

      assert_response :success, response.body
      canonicalize_json(response.body, :transform => filter_out_id)
    end

    batch = Batch.find_by_name(batch_name)

    # Confirm that batch was created
    assert batch.present?

    # and batch attributes match those expected
    assert_equal batch_name, batch.name
    assert_equal release_id, batch.release_id
    assert_equal DateTime.parse(release_date), batch.release_date
  end

  test "update batch" do
    new_description = 'Updated description!'
    with_baselines(@api, %r{\/update.json$}) do |file, id|
      put :update,
        :format => :json,
        :id => 1,
        :description => new_description
      assert_response :success, response.body
      canonicalize_json(response.body)
    end

    # Check description has been updated
    assert_equal new_description, Batch.find(1).description
  end

  test "update batch with empty name error" do
    with_baselines(@api, %r{\/update_name_error.json$}) do |file, id|
      put :update,
        :format => :json,
        :id => 1,
        :name => ''
      assert_response :unprocessable_entity, response.body
      canonicalize_json(response.body)
    end
  end

  test "update batch with invalid release error" do
    with_baselines(@api, %r{\/update_release_error.json$}) do |file, id|
      put :update,
        :format => :json,
        :id => 1,
        :release_name => 'no_such_release'
      assert_response :not_found, response.body
      canonicalize_json(response.body)
    end
  end

end
