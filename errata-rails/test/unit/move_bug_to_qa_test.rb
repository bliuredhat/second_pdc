require 'test_helper'

class MoveBugToQaTest < ActiveSupport::TestCase

  test "default move bug to ON_QA when added" do
    # Errata.where(:status => 'NEW_FILES')
    e = Errata.find(7517)

    # Bug.where('bug_status="MODIFIED" AND id NOT IN (SELECT bug_id FROM filed_bugs)')
    b = Bug.find(266861)

    fb = FiledBug.new(:errata => e, :bug => b)
    assert fb.valid?

    Bugzilla::TestRpc.any_instance.expects(:mark_bug_on_qa).once.with(b,e)

    force_sync_delayed_jobs(/^Bugzilla::/) do
      fb.save!
    end
  end

  test "bug 1007511 - different ON_QA behavior for EAP rebase bugs" do
    e = Errata.find(16375)

    mw_rebase_bug = Bug.find(698070)
    other_bug = Bug.find(698071)

    (mw_rebase_fb,other_fb) = [mw_rebase_bug,other_bug].map do |b|
      fb = FiledBug.new(:errata => e, :bug => b)
      assert_valid fb
      fb
    end

    markbug = lambda do |bug,errata|
      bug.was_marked_on_qa = 1
      bug.bug_status = 'ON_QA'
      bug.save
    end

    # when initially adding the bugs, only the non-rebase bug should be marked ON_QA
    Bugzilla::TestRpc.any_instance.expects(:mark_bug_on_qa).once.with(other_bug, e, &markbug)

    force_sync_delayed_jobs(/^Bugzilla::/) do
      mw_rebase_fb.save!
      other_fb.save!
    end

    # then, when moving the advisory to QE, the mw_rebase bug should be moved
    Bugzilla::TestRpc.any_instance.expects(:mark_bug_on_qa).once.with(mw_rebase_bug, e, &markbug)

    force_sync_delayed_jobs(/^Bugzilla::/) do
      e.change_state!('QE', secalert_user, 'moving to QE for test')
    end
  end

  test "bug 1007511 - different ON_QA behavior with rapid state changes" do
    e = Errata.find(16375)
    e.text_only_channel_list.set_channels_by_id([Channel.find(524)])

    mw_rebase_bug = Bug.find(698070)
    fb = FiledBug.new(:errata => e, :bug => mw_rebase_bug)
    assert_valid fb

    force_sync_delayed_jobs(/^Bugzilla::/) do
      fb.save!
    end

    # when moving the advisory to QE, the mw_rebase bug should be moved,
    # even if the state already changed from QE to something else by the time the job runs
    Bugzilla::TestRpc.any_instance.expects(:mark_bug_on_qa).once.with(mw_rebase_bug, e)

    jobs = capture_delayed_jobs(/^Bugzilla::/) do
      e.change_state!('QE', secalert_user)
      e.change_state!('REL_PREP', @secalart)
    end
    jobs.each(&:perform)
  end

  test "bug 1194276 - products with move_bugs_on_qe flag" do
    # Errata.where(:status => 'NEW_FILES')
    e = Errata.find(16654)

    # Create new bug
    b = Bug.create!(:bug_status => 'MODIFIED', :package => Package.find(16132), :short_desc => 'test bug')
    fb = FiledBug.new(:errata => e, :bug => b)
    assert fb.valid?

    # The bug status should not be changed when added
    Bugzilla::TestRpc.any_instance.expects(:mark_bug_on_qa).never
    force_sync_delayed_jobs(/^Bugzilla::/) do
      fb.save!
    end

    # The bugs for advisory move to ON_QA when advisory moves to QE
    # There are two bugs for this advisory (696512 and new one)
    Bugzilla::TestRpc.any_instance.expects(:mark_bug_on_qa).twice
    force_sync_delayed_jobs(/^Bugzilla::/) do
      e.change_state!('QE', secalert_user, 'moving to QE for test')
    end
  end

  test "bug 1125038 - display message of XMLRPC::FaultException in bug activity log" do
    # Errata.where(:status => 'NEW_FILES')
    errata = Errata.find(7517)
    # Bug.where('bug_status="MODIFIED" AND id NOT IN (SELECT bug_id FROM filed_bugs)')
    bug = Bug.find(266861)

    fb = FiledBug.new(:errata => errata, :bug => bug)
    assert fb.valid?

    exception_code = 1
    exception_message = 'For all JBoss Bugs, bla...'
    expected_error_message = "#{exception_code}: #{exception_message}"
    Bugzilla::TestRpc.any_instance.stubs(:mark_bug_on_qa).
      raises(XMLRPC::FaultException.new(exception_code, exception_message))

    assert_raises(XMLRPC::FaultException) do
      force_sync_delayed_jobs(/^Bugzilla::/) do
        fb.save!
      end
    end

    bug.reload
    log_message = bug.logs.where("message like ?", "%failed%").last.message
    assert_equal "Moving bug to ON_QA failed: XMLRPC::FaultException: #{expected_error_message}", log_message
  end

end
