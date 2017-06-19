require 'test_helper'

class SecurityActiveTest < ActionDispatch::IntegrationTest

  setup do
    @index_page = "/security/active"
  end

  test "PdcRHSA advisory is included" do
    auth_as secalert_user
    visit @index_page
    first(:link, 'RHSA-2017:11150').click

    assert first('.pdc-indicator').has_content? '[PDC]'
  end
end
