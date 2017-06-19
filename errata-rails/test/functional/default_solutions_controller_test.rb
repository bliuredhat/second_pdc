require 'test_helper'

class DefaultSolutionsControllerTest < ActionController::TestCase

  setup do
    auth_as releng_user
    @default_solution = DefaultSolution.find(3)
  end

  test "index" do
    get :index
    assert_response :success
    assert_template 'index'
  end

  test "show" do
    get :show, :id => @default_solution.id
    assert_response :success
    assert_template 'show'
  end

  test "edit" do
    get :edit, :id => @default_solution.id
    assert_response :success
    assert_template 'edit'
  end

  test "update" do
    [
      ['beep', '1', true],
      ['boop', '0', false]
    ].each do |text, active, expected_active|
      post :update, :id => @default_solution.id, :default_solution => { :text => text, :active => active }
      assert_redirected_to @default_solution
      assert_equal text, @default_solution.reload.text
      assert_equal expected_active, @default_solution.active?
    end
  end

end
