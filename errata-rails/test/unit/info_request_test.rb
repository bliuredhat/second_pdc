require 'test_helper'

class InfoRequestTest < ActiveSupport::TestCase

  # releng role has info_request_target and notify_same_role set,
  # so info request from a releng user results in email sent
  test "releng receives info requests from releng user" do
    releng = Role.find_by_name(:releng)
    assert releng.notify_same_role?
    assert_not_nil releng.info_request_target

    with_current_user(releng_user) do
      info_request_creates_mail(releng)
    end
  end

  # qa role does not have info_request_target
  test "qa does not receive info request mails" do
    qa = Role.find_by_name(:qa)
    assert_nil qa.info_request_target

    with_current_user(devel_user) do
      info_request_creates_mail(qa, false)
    end
  end

  # secalert role has info_request_target so info request from
  # a non-secalert user results in secalert receiving an email
  test "secalert receives info request mails from non-secalert user" do
    secalert = Role.find_by_name(:secalert)
    refute secalert.notify_same_role?
    assert_not_nil secalert.info_request_target

    with_current_user(devel_user) do
      info_request_creates_mail(secalert)
    end
  end

  # secalert role has notify_same_role=false so info request
  # from a secalert user results in no email being sent
  test "secalert does not receive info request mails from secalert user" do
    secalert = Role.find_by_name(:secalert)
    refute secalert.notify_same_role?
    assert_not_nil secalert.info_request_target

    with_current_user(secalert_user) do
      info_request_creates_mail(secalert, false)
    end
  end

  def create_info_request_for_role(role)
    InfoRequest.create!(
      :errata => rhba_async,
      :summary => 'info',
      :description => 'info',
      :info_role => role
    )
  end

  def info_request_creates_mail(role, expect_info_target=true)
    assert_difference('ActionMailer::Base.deliveries.length', 1) do
      create_info_request_for_role(role)
    end

    mail = ActionMailer::Base.deliveries.last
    actual_recipients = mail.header['to'].addrs.map(&:to_s)

    expected_recipients = rhba_async.notify_and_cc_emails
    expected_recipients << role.info_request_target if expect_info_target
    expected_recipients.uniq!

    assert_array_equal expected_recipients, actual_recipients
    assert_equal 'INFO_REQUEST', mail.header['x-erratatool-action'].to_s
  end

end
