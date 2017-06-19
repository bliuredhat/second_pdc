require 'test_helper'

class BlockingIssueTest < ActiveSupport::TestCase
  test "Bug 618235 - NEED_INFO from releng doesn't notify anybody" do
    before = ActionMailer::Base.deliveries.length
    releng = Role.find_by_name('releng')
    releng.blocking_issue_target = 'release-engineering@redhat.com'
    releng.save!
    
    issue = BlockingIssue.create!(:errata => rhba_async,
                                  :who => qa_user,
                                  :summary => 'block',
                                  :description => 'block',
                                  :blocking_role => releng
                                  )
    after = ActionMailer::Base.deliveries.length
    assert_equal(1, (after - before))
    mail = ActionMailer::Base.deliveries.last
    assert_match 'release-engineering@redhat.com', mail.header['to'].to_s
    assert_equal 'BLOCKED', mail.header['x-erratatool-action'].to_s
  end
  
  test "Bug 592981  After changing state to: BLOCKED ON, it cannot be unset by any other user" do
    issue = BlockingIssue.create!(:errata => rhba_async, 
                                  :who => qa_user,
                                  :summary => 'block',
                                  :description => 'block',
                                  :blocking_role => Role.find_by_name('qa')
                                  )

    assert rhba_async.is_blocked?
    assert rhba_async.can_clear_blocking_issue?(qa_user)
    assert rhba_async.can_clear_blocking_issue?(secalert_user)
    assert rhba_async.can_clear_blocking_issue?(admin_user)
    assert !rhba_async.can_clear_blocking_issue?(devel_user)
    assert !rhba_async.can_clear_blocking_issue?(pm_user)
    assert_raises(ActiveRecord::RecordInvalid) { rhba_async.change_state!(State::QE, qa_user)}
  end

  # secalert role has blocking_issue_target so blocking issue from
  # a non-secalert user results in an email being sent
  test "secalert receives blocking issue mails from non-secalert user" do
    secalert = Role.find_by_name(:secalert)
    refute secalert.notify_same_role?
    assert_not_nil secalert.blocking_issue_target

    with_current_user(devel_user) do
      blocking_issue_creates_mail(secalert)
    end
  end

  # secalert role has notify_same_role=false so blocking issue
  # from a secalert user results in no email being sent
  test "secalert does not receive blocking issue mails from secalert user" do
    secalert = Role.find_by_name(:secalert)
    refute secalert.notify_same_role?
    assert_not_nil secalert.blocking_issue_target

    with_current_user(secalert_user) do
      blocking_issue_creates_mail(secalert, false)
    end
  end

  def create_blocking_issue_for_role(role)
    BlockingIssue.create!(
      :errata => rhba_async,
      :summary => 'block',
      :description => 'block',
      :blocking_role => role
    )
  end

  def blocking_issue_creates_mail(role, expect_blocking_issue_target=true)
    assert_difference('ActionMailer::Base.deliveries.length', 1) do
      create_blocking_issue_for_role(role)
    end

    mail = ActionMailer::Base.deliveries.last
    actual_recipients = mail.header['to'].addrs.map(&:to_s)

    expected_recipients = rhba_async.notify_and_cc_emails
    expected_recipients << role.blocking_issue_target if expect_blocking_issue_target
    expected_recipients.uniq!

    assert_array_equal expected_recipients, actual_recipients
    assert_equal 'BLOCKED', mail.header['x-erratatool-action'].to_s
  end

end
