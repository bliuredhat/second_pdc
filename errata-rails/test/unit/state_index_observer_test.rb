require 'test_helper'

class StateIndexObserverToPushReadyTest < ActiveSupport::TestCase
  setup do
    @errata = Errata.find(11118)

    assert_equal [
      'REL_PREP',
      []
    ], [
      @errata.status,
      @errata.push_ready_blockers
    ], "testdata problem: test advisory doesn't satisfy preconditions"

    # no current fixtures satisfy this precondition, just hack it
    @errata.release.update_attribute(:is_async, true)
  end

  # Bug 1080406, error case.
  # If filing a ticket with rel-eng fails, advisory can't be moved to PUSH_READY, and a failure
  # comment is posted.
  test "REL_PREP to PUSH_READY rolls back with comment if releng ticket can't be filed" do
    rel_prep_to_push_ready_test(
      :can_deliver_mail => false,
      :expect_error => true,
      :expected_status => 'REL_PREP',
      :expected_comments => [
        %r{^ERROR:.*problem occurred.*: simulated error.*advisory could not be moved to PUSH_READY}m
      ]
    )
  end

  # Bug 1080406, success case.
  # If filing a ticket with rel-eng succeeds, advisory is moved to PUSH_READY, with
  # appropriate comments.
  test "REL_PREP to PUSH_READY succeeds if releng ticket can be filed" do
    rel_prep_to_push_ready_test(
      :can_deliver_mail => true,
      :expect_error => false,
      :expected_status => 'PUSH_READY',
      :expected_comments => [
        'A request to push this erratum live has been filed.',
        'Changed state from REL_PREP to PUSH_READY'
      ]
    )
  end

  test 'IN_PUSH to PUSH_READY does not result in push request comment or email' do
    e = Errata.find(23101)
    assert_equal State::IN_PUSH, e.status
    assert_difference('e.comments.count', 1) do
      assert_difference('ActionMailer::Base.deliveries.length', 1) do
        e.change_state!(State::PUSH_READY, admin_user)
      end
    end
    assert_equal 'Changed state from IN_PUSH to PUSH_READY', e.comments.last.text
    assert_equal 'StateChangeComment', e.comments.last.type
    assert_no_match /Live push request/, ActionMailer::Base.deliveries.last.subject
  end

  test 'push request mail is not sent for non-async' do
    Notifier.expects(:request_rhnlive_push).never

    @errata.release.update_attribute(:is_async, false)
    @errata.reload.change_state!('PUSH_READY', qa_user)
  end

  test 'push request mail is sent for RHBA' do
    Notifier.expects(:request_rhnlive_push).
      returns(mock.tap{|m| m.expects(:deliver)}).once

    assert_equal 'RHBA', @errata.errata_type
    @errata.change_state!('PUSH_READY', qa_user)
  end

  test 'push request mail is sent for RHSA' do
    Notifier.expects(:request_rhnlive_push).
      returns(mock.tap{|m| m.expects(:deliver)}).once

    @errata.stubs(:errata_type => 'RHSA', :security_approved? => true)
    assert @errata.is_security?
    @errata.change_state!('PUSH_READY', qa_user)
  end

  test 'push request mail is not sent for E2E tests' do
    Notifier.expects(:request_rhnlive_push).never

    @errata.stubs(:is_end_to_end_test? => true)
    assert_equal 'RHBA', @errata.errata_type
    @errata.change_state!('PUSH_READY', qa_user)
  end

  def rel_prep_to_push_ready_test(args)
    mail = mock()
    Notifier.expects(:request_rhnlive_push).with(@errata).returns(mail).once
    mail.expects(:deliver).once.tap{|x| x.raises('simulated error') unless args[:can_deliver_mail]}

    old_comments = @errata.comments.to_a

    e = nil
    begin
      @errata.change_state!('PUSH_READY', qa_user)
    rescue StandardError => e
    end

    if args[:expect_error]
      assert_not_nil e, 'error should have been raised'
    else
      assert_nil e, 'error should not have been raised'
    end

    # in the rollback case, reload is necessary to see the final state
    @errata.reload

    assert_equal args[:expected_status], @errata.status

    created_comments = (@errata.comments.to_a - old_comments).map(&:text)
    expected_comments = args[:expected_comments]

    [created_comments,expected_comments].map(&:length).tap do |e,a|
      assert_equal e, a, "expected #{e} comments but got #{a}:\n#{created_comments.join("\n-----\n")}"
    end

    i = 1
    expected_comments.zip(created_comments) do |e,a|
      assert_match e, a, "mismatch on comment #{i}"
      i += 1
    end
  end
end

class StateIndexObserverBatchToPushReadyLiveTest < ActiveSupport::TestCase
  def setup_advisory(erratum, opts=[])
    @errata = Errata.find(erratum)
    # Advisory must be in REL_PREP and set for a push request
    assert_equal [
      'REL_PREP',
      []
    ], [
      @errata.status,
      @errata.push_ready_blockers
    ], "testdata problem: test advisory doesn't satisfy preconditions"

    if opts[:set_async]
      @errata.release.update_attribute(:is_async, true)
    end
    if opts[:set_batch]
      # Note: the release must allow batches; choose errata accordingly.
      @batch = Batch.create(:release_id => @errata.release.id,
                            :release_date => Time.now,
                            :name => "batch for #{name}",  # Test Name
                            :description => 'test batch')
      @errata.update_attributes(:batch_id => @batch.id,
                                :is_batch_blocker => true)
    end
  end

  test 'push request email address check for batch RHSA' do
    setup_advisory(19463, :set_async => true, :set_batch => true)
    mailbox = generate_mail('PUSH_READY', 'PUSH-REQUEST')
    assert_equal 1, mailbox.count, "Only one PUSH-REQUEST email should be generated, got: #{mailbox.count}"
    check_recipients(mailbox.first,
                     %w(release-engineering@redhat.com),
                     %w(security-response@redhat.com))
  end

  test 'push request email address check for non-batch RHSA' do
    setup_advisory(19463, :set_async => true)
    mailbox = generate_mail('PUSH_READY', 'PUSH-REQUEST')
    assert_equal 1, mailbox.count, "Only one PUSH-REQUEST email should be generated, got: #{mailbox.count}"
    check_recipients(mailbox.first,
                     [],
                     %w(release-engineering@redhat.com security-response@redhat.com))
  end

  test 'push request email address check for batch RHBA' do
    setup_advisory(11118, :set_async => true, :set_batch => true)
    mailbox = generate_mail('PUSH_READY', 'PUSH-REQUEST')
    assert_equal 1, mailbox.count, "Only one PUSH-REQUEST email should be generated, got: #{mailbox.count}"
    check_recipients(mailbox.first,
                     %w(release-engineering@redhat.com),
                     %w(security-response@redhat.com))
  end

  test 'push request email address check for non-batch RHBA' do
    setup_advisory(11118, :set_async => true)
    mailbox = generate_mail('PUSH_READY', 'PUSH-REQUEST')
    assert_equal 1, mailbox.count, "Only one PUSH-REQUEST email should be generated, got: #{mailbox.count}"
    check_recipients(mailbox.first,
                     %w(release-engineering@redhat.com),
                     %w(security-response@redhat.com))
  end

  def generate_mail(via_state, for_action)
    ActionMailer::Base.deliveries.clear
    @errata.change_state!(via_state, qa_user)
    mailbox = ActionMailer::Base.deliveries
    mailbox.select{|msg| msg.header[Notifier::ACTION_HEADER].to_s == for_action}
  end

  def check_recipients(msg, yes_list, no_list)
    [[yes_list, true], [no_list, false]].each do |list, expect|
      words = expect ? 'should' : 'should not'
      list.each do |address|
        assert_equal expect, msg.to.include?(address), "Mail #{words} go to #{address}"
      end
    end
  end
end

class StateIndexObserverToShippedLiveTest < ActiveSupport::TestCase
  setup do
    @errata = Errata.find(23101)
    @errata.stubs(:push_ready_blockers => [])
    refute releng_user.in_role?('secalert')
    assert secalert_user.in_role?('secalert')
    assert_equal [
      'IN_PUSH',
      true
    ], [
      @errata.status,
      @errata.is_security?
    ], "testdata problem: test advisory doesn't satisfy preconditions"
    ActionMailer::Base.deliveries = []
  end

  test 'email content testing' do
    # Use static version number in the mail so we don't need to update the test
    # for each new version
    with_stubbed_const({:VERSION => '3.11.8-0'}, SystemVersion) do
      @errata.change_state!('SHIPPED_LIVE', releng_user)
    end

    mail = ActionMailer::Base.deliveries.first
    assert_testdata_equal "rhsa_shipped_live/notification_to_secalert.txt", formatted_mail(mail)
  end

  test 'non product security user pushes RHSA' do
    verify_notification_to_secalert(
      :user => releng_user,
      :send_email => true,
      :can_deliver_mail => true,
      :expected_status => 'SHIPPED_LIVE',
      :expected_comments => [
        'A notification to Product Security team has been filed.',
        'Changed state from IN_PUSH to SHIPPED_LIVE'
      ]
    )
  end

  test 'product security user pushes RHSA' do
    verify_notification_to_secalert(
      :user => secalert_user,
      :can_deliver_mail => false,
      :expected_status => 'SHIPPED_LIVE',
      :expected_comments => ['Changed state from IN_PUSH to SHIPPED_LIVE']
    )
  end

  test 'email failed when non Product Security user pushes RHSA' do
    verify_notification_to_secalert(
      :user => releng_user,
      :send_email => true,
      :can_deliver_mail => false,
      :expect_error => true,
      :expected_status => 'IN_PUSH',
      :expected_comments => [
        %r{^ERROR:.*problem occurred.*: simulated error.*advisory could not be moved to SHIPPED_LIVE}m
      ]
    )
  end

  def verify_notification_to_secalert(args)
    if args[:send_email]
      mail = mock()
      Notifier.expects(:rhsa_shipped_live).with(@errata, args[:user]).returns(mail).once
      mail.expects(:deliver).once.tap{|x| x.raises('simulated error') unless args[:can_deliver_mail]}
    elsif
      Notifier.expects(:rhsa_shipped_live).never
    end
    old_comments = @errata.comments.to_a

    e = nil
    begin
      @errata.change_state!('SHIPPED_LIVE', args[:user])
    rescue StandardError => e
    end

    if args[:expect_error]
      assert_not_nil e, 'error should have been raised'
    else
      assert_nil e, 'error should not have been raised'
    end
    @errata.reload

    assert_equal args[:expected_status], @errata.status

    created_comments = (@errata.comments.to_a - old_comments).map(&:text)
    expected_comments = args[:expected_comments]

    [created_comments,expected_comments].map(&:length).tap do |e,a|
      assert_equal e, a, "expected #{e} comments but got #{a}:\n#{created_comments.join("\n-----\n")}"
    end

    i = 1
    expected_comments.zip(created_comments) do |e,a|
      assert_match e, a, "mismatch on comment #{i}"
      i += 1
    end
  end

end
