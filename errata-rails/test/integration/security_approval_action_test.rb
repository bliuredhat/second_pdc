require 'test_helper'

class SecurityApprovalActionTest < ActionDispatch::IntegrationTest

  test "request approval by UI" do
    auth_as devel_user

    e = rel_prep_unrequested_rhsa
    visit "/advisory/#{e.id}"
    click_on 'Request Approval'

    assert has_text?('Product Security approval has been requested.'), page.html
    assert e.reload.security_approval_requested?
  end

  test "approve by UI" do
    auth_as secalert_user

    e = rel_prep_requested_rhsa
    visit "/advisory/#{e.id}"
    click_on 'Approve'

    assert has_text?('Product Security approval has been granted.'), page.html
    assert e.reload.security_approved?
  end

  test "disapprove by UI" do
    auth_as devel_user

    e = rel_prep_approved_rhsa
    visit "/advisory/#{e.id}"
    click_on 'Disapprove'

    assert has_text?('Product Security approval has been rescinded.'), page.html
    refute e.reload.security_approved?
  end

  def rel_prep_unrequested_rhsa
    Errata.find(11138)
  end

  def rel_prep_requested_rhsa
    Errata.find(11133)
  end

  def rel_prep_approved_rhsa
    Errata.find(19463)
  end
end
