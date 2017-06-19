require 'test_helper'

class ErrataHelperTest < ActiveSupport::TestCase
  include ErrataHelper
  include ActionView::Helpers::NumberHelper

  setup do
     @rhba = RHBA.find(7517)
  end

  test "jira issue status text" do
    Settings.jira_always_shown_states = ['In Progress', 'Done']
    result = jira_issue_status_stats_text(@rhba)
    assert !result.empty?, "the result should contains a list of states text"
    assert_match /In Progress\:\s+2/, result
    assert_match /Done\:\s+1/, result
  end
end
