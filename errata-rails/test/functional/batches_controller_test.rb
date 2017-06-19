require 'test_helper'

class BatchesControllerTest < ActionController::TestCase
  setup do
    auth_as releng_user
  end

  test "index" do
    get :index
    assert_response :success
    assert_template 'index'
  end

  test "show" do
    get :show, :id => 1
    assert_response :success
    assert_template 'batches/show'
  end

  test "edit" do
    get :edit, :id => 1
    assert_response :success
    assert_template 'batches/edit'
  end

  test "new" do
    get :new
    assert_response :success
    assert_template 'batches/new'
  end

  test "create without name" do
    assert_no_difference('Batch.count') do
      post :create
    end
    batch_name_line = response.body.split(/\n/).select{|line| line =~ /id="batch_name"/}.first
    assert_match /class="field_with_errors".*<input id="batch_name"/, batch_name_line, batch_name_line
    assert_response :success
  end

  test "create" do
    post :create, :batch => {:release_id => 452, :name => 'create_test_batch'}
    assert_response :redirect
    batch = Batch.find_by_name('create_test_batch')

    # New batch has been created
    assert batch.present?

    # and has expected release_id
    assert_equal 452, batch.release_id
  end

  test "create as unauthorized user" do
    auth_as devel_user
    assert_no_difference('Batch.count') do
      post :create, :batch => {:release_id => 452, :name => 'create_test_batch'}
    end
    assert_response :unauthorized

    # Batch should not be created
    refute Batch.find_by_name('create_test_batch').present?
  end

  test "update" do
    put :update, :id => 1, :batch => {:description => 'updated description'}
    assert_response :redirect

    # Description should have updated
    assert_equal 'updated description', Batch.find(1).description
  end

  test "update with empty name" do
    batch_name = Batch.find(1).name
    put :update, :id => 1, :batch => {:name => ''}
    batch_name_line = response.body.split(/\n/).select{|line| line =~ /id="batch_name"/}.first
    assert_match /class="field_with_errors".*<input id="batch_name"/, batch_name_line, batch_name_line
    assert_response :success

    # Name should not have changed
    assert_equal batch_name, Batch.find(1).name
  end

end
