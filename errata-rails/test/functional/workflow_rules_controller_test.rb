require 'test_helper'

class WorkflowRulesControllerTest < ActionController::TestCase
  setup do
    auth_as admin_user
  end

  test 'can show index successfully' do
    get :index
    assert_response :success, response.body
  end

  test 'can show a specific rule set successfully' do
    # find first, to ensure the ruleset exists
    ruleset = StateMachineRuleSet.find(1)
    get :show, :id => ruleset.id
    assert_response :success, response.body
  end
end
