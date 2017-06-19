require 'test_helper'

class NotifyPartnersJobTest < ActiveSupport::TestCase
  setup do
    ActionMailer::Base.deliveries = []
  end

  test 'enqueues only for advisory with correct product' do
    assert_difference('Delayed::Job.count') do
      # RHEL does notify partners
      e = Errata.find(20836)
      assert_equal 'RHEL', e.product.short_name
      NotifyPartnersJob.maybe_enqueue(e.current_state_index)
    end

    assert_difference('Delayed::Job.count') do
      # supplementary does notify partners
      e = Errata.find(19707)
      assert_equal 'LACD', e.product.short_name
      NotifyPartnersJob.maybe_enqueue(e.current_state_index)
    end

    assert_no_difference('Delayed::Job.count') do
      # JBEAP does not notify partners
      e = Errata.find(20292)
      assert_equal 'JBEAP', e.product.short_name
      NotifyPartnersJob.maybe_enqueue(e.current_state_index)
    end
  end

  test 'should not send mail if advisory was respun' do
    e = Errata.find(18894)

    # This advisory went to NEW_FILES twice
    from_new_files = e.state_indices.reorder('id asc').where(:previous => 'NEW_FILES').to_a
    assert_equal 2, from_new_files.length

    # When it went to NEW_FILES the second time, it had dropped a build
    assert ErrataBrewMapping.dropped_at_index(from_new_files[1].prior_index).present?

    # A notification for the first transition from NEW_FILES should be ignored,
    # since it was pre-empted by later notification jobs due to respin
    job = NotifyPartnersJob.new(from_new_files[0])

    logs = run_with_logs(job)

    # Should have sent nothing and should not run again
    refute job.rerun?
    assert_equal [], ActionMailer::Base.deliveries

    assert_match %r{\bDropping partner notification for RHSA-2014:18894-01: respun at 2014-09-29\b}, logs
  end

  test 'should not send job if advisory is currently NEW_FILES' do
    e = Errata.find(19828)

    assert_equal 'QE', e.status

    # Notification enqueued for the advisory's current state...
    job = NotifyPartnersJob.new(e.current_state_index)

    # Now advisory moves NEW_FILES
    e.change_state!('NEW_FILES', User.current_user)

    # Clear any mails sent during the state changes
    ActionMailer::Base.deliveries = []

    # The job, if run now, should not send its notification
    logs = run_with_logs(job)

    assert_equal 'Wrong status NEW_FILES to notify for RHBA-2015:19828-01', logs
    assert_equal [], ActionMailer::Base.deliveries

    # It should want to rerun later since the advisory might come out of
    # NEW_FILES
    assert job.rerun?
  end

  test 'prior job should send mail if advisory moved back to NEW_FILES with no changes' do
    # In this case, a notification was enqueued, then an advisory was moved back
    # to NEW_FILES and then QE again with no builds or bugs added or removed.
    #
    # The original notification should still be sent in that case, and no
    # further notification enqueued.
    e = Errata.find(19828)

    assert_equal 'QE', e.status

    # Notification enqueued for the advisory's current state...
    original_job = NotifyPartnersJob.new(e.current_state_index)

    # Now advisory moves -> NEW_FILES -> QE, but with no builds/bugs added.
    # It should not create any new notification jobs
    later_jobs = capture_delayed_jobs(/NotifyPartnersJob/) do
      e.change_state!('NEW_FILES', User.current_user)
      e.change_state!('QE', User.current_user)
    end

    assert_equal [], later_jobs

    # Clear any mails sent during the state changes
    ActionMailer::Base.deliveries = []

    # The original job, if run now, should still send its notification
    logs = run_with_logs(original_job)

    # Should have sent a mail and should not run again
    refute original_job.rerun?
    assert_equal 1, ActionMailer::Base.deliveries.length, logs
  end

  test 'should drop notification for SHIPPED_LIVE errata' do
    ignores_status_test(20466, 'SHIPPED_LIVE')
  end

  test 'should drop notification for DROPPED_NO_SHIP errata' do
    ignores_status_test(11020, 'DROPPED_NO_SHIP')
  end

  def ignores_status_test(errata_id, status)
    e = Errata.find(errata_id)

    assert_equal status, e.status

    index = e.state_indices.reorder('id asc').where(:current => 'QE').last

    job = NotifyPartnersJob.new(index)
    logs = run_with_logs(job)

    # Should have sent nothing and should not run again
    refute job.rerun?
    assert_equal [], ActionMailer::Base.deliveries

    assert_match %r{Dropping partner notification for #{e.fulladvisory}: #{status}}, logs
  end


  test 'should retry later when not yet partner accessible' do
    Settings.partner_notify_check_interval = 90.minutes

    e = Errata.find(18894)

    index = e.state_indices.reorder('id asc').where(:current => 'QE').last

    # Freeze time for accurate comparison during this test
    Time.stubs(:now => index.created_at + 5.hours)

    e.class.any_instance.stubs(:allow_partner_access? => false)

    job = NotifyPartnersJob.new(index)
    logs = run_with_logs(job)

    # Should have sent nothing, but should try again later
    assert job.rerun?
    assert_equal [], ActionMailer::Base.deliveries
    assert_equal job.next_run_time, 90.minutes.from_now

    assert_match %r{Not safe to send partner notification for RHSA-2014:18894-01}, logs
  end

  test 'sends partners_new_errata on first move to QE' do
    e = Errata.find(19828)

    to_qe = e.state_indices.reorder('id asc').where(:current => 'QE')
    assert_equal 1, to_qe.length

    e.class.any_instance.stubs(:allow_partner_access? => true)

    job = NotifyPartnersJob.new(to_qe[0])
    logs = run_with_logs(job)

    # Should have sent the expected mail and should not run again
    refute job.rerun?
    assert_equal 1, ActionMailer::Base.deliveries.length
    assert ActionMailer::Base.deliveries[0].subject.include?('is now available for partner testing')
  end

  test 'sends partners_changed_files on non-first move to QE' do
    e = Errata.find(18894)

    to_qe = e.state_indices.reorder('id asc').where(:current => 'QE').to_a
    assert to_qe.length > 1

    e.class.any_instance.stubs(:allow_partner_access? => true)

    job = NotifyPartnersJob.new(to_qe[-1])
    logs = run_with_logs(job)

    # Should have sent the expected mail and should not run again
    refute job.rerun?
    assert_equal 1, ActionMailer::Base.deliveries.length
    assert ActionMailer::Base.deliveries[0].subject.include?('has new files')
  end

  # Run the partner notification job, capturing all log messages, and returning
  # the total log text as a string.
  def run_with_logs(job)
    capture_logs do
      job.perform
    end.map{ |log| log[:msg] }.join("\n")
  end
end
