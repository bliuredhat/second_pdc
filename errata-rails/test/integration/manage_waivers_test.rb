require 'test_helper'

class ManageWaiversTest < ActionDispatch::IntegrationTest

  test "request waivers" do
    e = Errata.find(10808)
    comment_count = e.comments.count
    mail_count = ActionMailer::Base.deliveries.count

    auth_as devel_user
    visit "/rpmdiff/manage_waivers/#{e.id}"

    r1 = RpmdiffResult.find(682031)
    r2 = RpmdiffResult.find(760560)
    r3 = RpmdiffResult.find(760561)

    assert r1.rpmdiff_waivers.empty?
    assert r2.rpmdiff_waivers.empty?
    assert r3.rpmdiff_waivers.empty?

    assert_equal RpmdiffScore::NEEDS_INSPECTION, r3.score

    assert page.has_text?('Failures For Your Review'), page.html

    check 'request_waiver[760560]'
    check 'request_waiver[760561]'

    fill_in 'waive_text[760560]', with: 'first waiver', visible: false
    fill_in 'waive_text[760561]', with: 'second waiver', visible: false

    click_button 'Request Waivers'

    assert page.has_text?('Requested waivers for 2 tests.'), page.html

    [r1,r2,r3].each(&:reload)
    assert r1.rpmdiff_waivers.empty?
    assert_equal ['first waiver'], r2.rpmdiff_waivers.pluck(:description)
    assert_equal ['second waiver'], r3.rpmdiff_waivers.pluck(:description)
    assert_equal [devel_user], r2.rpmdiff_waivers.map(&:user)
    assert_equal [devel_user], r3.rpmdiff_waivers.map(&:user)
    assert_equal RpmdiffScore::WAIVED, r2.score
    assert_equal RpmdiffScore::WAIVED, r3.score
    w2 = r2.rpmdiff_waivers.first
    w3 = r3.rpmdiff_waivers.first
    refute w2.acked?
    refute w3.acked?

    # still shows the last unwaived result
    assert page.has_text?('Failures For Your Review'), page.html
    assert page.has_field?('request_waiver[682031]'), page.html
    refute page.has_field?('request_waiver[760560]'), page.html
    refute page.has_field?('request_waiver[760561]'), page.html

    # those waivers can now be reviewed - but not by this user
    assert page.has_text?('Waivers For Review'), page.html

    auth_as qa_user
    visit page.current_url

    # can now be reviewed by current user
    assert page.has_text?('Waivers For Your Review'), page.html

    find(:xpath, "//button[@data-id='#{w2.id}'][text()='Approve']").click
    find(:xpath, "//button[@data-id='#{w3.id}'][text()='Reject']").click
    # TODO: actually, the above clicks don't do anything other than test that the element exists.
    # On the page, the clicks are handled by javascript, which our test driver doesn't execute.
    # That's why we have to directly modify hidden input fields as well.
    find(:xpath, "//input[@name='ack[#{w2.id}]']", visible: false).set('approve')
    find(:xpath, "//input[@name='ack[#{w3.id}]']", visible: false).set('reject')
    fill_in "ack_text[#{w2.id}]", with: 'This looks OK.', visible: false
    fill_in "ack_text[#{w3.id}]", with: 'Not acceptable.', visible: false
    click_button 'Submit'

    assert page.has_text?('Approved 1 waiver.'), page.html
    assert page.has_text?('Rejected 1 waiver.'), page.html

    # no more waivers to be reviewed
    refute page.has_text?('Waivers For Your Review'), page.html
    refute page.has_text?('Waivers For Review'), page.html

    [w2,w3].each(&:reload)
    assert w2.acked?
    assert_equal qa_user, w2.acked_by
    refute w3.acked?

    unwaiver = begin
      all_waivers = w3.rpmdiff_result.rpmdiff_waivers.order('waiver_id ASC')
      assert_equal 2, all_waivers.count
      assert_equal w3, all_waivers.first
      all_waivers.second
    end

    assert_equal 'Not acceptable.', unwaiver.description
    assert_equal qa_user, unwaiver.person
    assert_equal RpmdiffScore::WAIVED, unwaiver.old_result

    r3.reload
    assert_equal RpmdiffScore::NEEDS_INSPECTION, r3.score

    # Embedded history should show the waive and unwaive
    pagehtml = page.html
    ['Waived by Devel User', 'second waiver', 'Unwaived by Qa User', 'Not acceptable.'].each do |text|
      # page.has_text? fails to match these for unknown reasons; maybe because the elements are hidden?
      # has_text?(:all, text) and Capybara.ignore_hidden_elements = false don't help.
      assert pagehtml.include?(text), "missing #{text}:\n#{pagehtml}"
    end

    e.reload
    assert_equal comment_count+2, e.comments.count
    (ack_nack_comment, waive_comment) = Comment.where(:errata_id => e).order('id DESC').limit(2).to_a
    assert_equal devel_user, waive_comment.who
    assert_equal qa_user, ack_nack_comment.who

    # should be a single comment for both waivers
    assert_match %r<RPMDiff Run 47686, test "Erratum manifest" has been waived
http://.+
first waiver

RPMDiff Run 47686, test "Install log" has been waived
http://.+
second waiver>, waive_comment.text

    assert_match %r<RPMDiff Run 47686, test "Erratum manifest" waiver has been approved
http://.+
This looks OK\.>, ack_nack_comment.text

    assert_match %r<RPMDiff Run 47686, test "Install log" has been unwaived
http://.+
Not acceptable\.>, ack_nack_comment.text

    # FIXME: why is this necessary?  after_commit in CommentSweeper is not getting called without it.
    # after_commit callbacks obviously are generally working, since one of them is creating the comments
    # in the first place.  Maybe two levels of after_commit are not working?
    [ack_nack_comment, waive_comment].each{|c| Comment.notify_observers :after_commit, c}

    mails = ActionMailer::Base.deliveries[mail_count..-1]
    mailstr = mails.map(&:to_s).join("\n--------------\n")
    assert_equal 2, mails.count, mailstr
    assert_mail_include ack_nack_comment.text, mails[0]
    assert_mail_include waive_comment.text, mails[1]
  end

  def assert_mail_include(str, mail)
    body_str = mail.body.to_s
    assert body_str.include?(str), "mail failed to contain string:\n#{str}\nMail body:\n#{body_str}"
  end
end
