require 'test_helper'

class TcmsControllerTest < ActionController::TestCase
  def setup
    auth_as qa_user
    @errata_1 = RHBA.qe.last
    @errata_2 = RHEA.qe.last
    @orig_plan_count_1 = @errata_1.nitrate_test_plans.count
    @orig_plan_count_2 = @errata_2.nitrate_test_plans.count
  end

  test "adding test plans" do
    new_plan_id = 98765

    # Can add a plan
    post 'add_test_plan', :id => @errata_1.id, :plan => { :id => new_plan_id }
    assert_response :success, response.body
    assert_match "Plan #{new_plan_id}", response.body
    assert_equal @orig_plan_count_1 + 1, @errata_1.reload.nitrate_test_plans.count

    # Can't add a dupe
    post 'add_test_plan', :id => @errata_1.id, :plan => { :id => new_plan_id }
    assert_response :success, response.body
    assert_match "Test plan #{new_plan_id} already added", response.body
    assert_equal @orig_plan_count_1 + 1, @errata_1.reload.nitrate_test_plans.count

    # Can't add one already added
    post 'add_test_plan', :id => @errata_2.id, :plan => { :id => new_plan_id }
    assert_response :success, response.body
    assert_match "Test plan #{new_plan_id} already associated with", response.body
    assert_equal @orig_plan_count_2, @errata_2.reload.nitrate_test_plans.count

  end
  test "can't add bad test plan ids" do
    [-1, 0, 9999999999999999999, 1.2, "01234", "foo"].each do |bad_id|
      post 'add_test_plan', :id => @errata_1.id, :plan => { :id => bad_id }
      assert_response :success, response.body
      # The message is shown dynamically via an RJS response hence can't just check flash[:error]
      assert_match "Please enter an integer plan id between 1 and 2147483647.", response.body
      assert_equal @orig_plan_count_1, @errata_1.reload.nitrate_test_plans.count
    end
  end

end
