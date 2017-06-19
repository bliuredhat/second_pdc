require 'test_helper'

class RpmdiffHelperTest < ActiveSupport::TestCase
  include RpmdiffHelper
  include ActionView::Helpers
  include ActionDispatch::Routing
  include Rails.application.routes.url_helpers
  include ApplicationHelper

  test 'shows no edit link if autowaive rule is active for qa user' do
    with_current_user(admin_user) do
      rule = rpmdiff_autowaive_rule(:active => true)
      result = list_autowaive_rules_actions(rule, qa_user)
      assert_no_match %r{\bEdit\b}, result
    end
  end

  test 'shows edit link if autowaive rule is active for devel user' do
    with_current_user(admin_user) do
      rule = rpmdiff_autowaive_rule(:active => true)
      result = list_autowaive_rules_actions(rule, devel_user)
      assert_match %r{\bEdit\b}, result
    end
  end

  test 'shows edit link if autowaive rule is not active for devel user' do
    rule = rpmdiff_autowaive_rule
    rule.update_attribute(:active, false)

    result = list_autowaive_rules_actions(rule, devel_user)
    assert_match %r{\bEdit\b}, result
  end

  test 'shows action links if user is admin' do
    with_current_user(admin_user) do
      result = list_autowaive_rules_actions(rpmdiff_autowaive_rule(:active => true), admin_user)
      assert_match %r{\bEdit\b}, result
    end
  end

  test 'autowaive link condition is true for score which can be autowaived' do
    assert show_create_autowaive_link?(admin_user, RpmdiffScore::FAILED)
  end

  test 'autowaive link condition is false for score which can not be autowaived' do
    refute show_create_autowaive_link?(admin_user, RpmdiffScore::TEST_IN_PROGRESS)
  end
end
