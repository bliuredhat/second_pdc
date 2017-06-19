require 'test_helper'

class ListRequestsFormTest < ActionDispatch::IntegrationTest

  #
  # Bug 772892
  # For some reason ASYNC is no longer appearing in the list of releases
  #
  # TODO: Update for 2.3 UI.
  #
  #test "async is visible in release select" do
  #  auth_as admin_user
  #  visit '/errata/listrequest.cgi'
  #  assert page.find('#errata_group_id option').has_content? "ASYNC"
  #end

end

