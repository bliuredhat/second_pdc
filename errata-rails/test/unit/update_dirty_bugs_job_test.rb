require 'test_helper'

class UpdateDirtyBugsJobTest < ActiveSupport::TestCase
  setup do
    # We run all delayed jobs during this test, so clean them first to
    # ensure no unrelated code runs
    Delayed::Job.delete_all
  end

  test "perform no dirty" do
    Bug.expects(:make_from_rpc).never

    DirtyBug.delete_all
    Bugzilla::UpdateDirtyBugsJob.new.perform
  end

  test "perform some dirty" do
    # delete all dirty bugs before proceeding
    DirtyBug.delete_all
    bugs = Bug.order("id asc").limit(10).to_a
    test_rpc_bugs = prepare_dirty_bugs(bugs)

    opts = { :permissive => true }
    Bugzilla::Rpc.any_instance.expects(:get_bugs).with(bugs[0..3].map(&:bug_id), opts).returns(test_rpc_bugs[0..3])
    # XMLRPC::Error returns []
    Bugzilla::Rpc.any_instance.expects(:get_bugs).with(bugs[4..5].map(&:bug_id), opts).returns([])
    # Fetches partail records - Bug 7 is inaccessible so returns 4..6
    Bugzilla::Rpc.any_instance.expects(:get_bugs).with(bugs[4..7].map(&:bug_id), opts).returns(test_rpc_bugs[4..6])
    # 8, 9 works fine
    Bugzilla::Rpc.any_instance.expects(:get_bugs).with(bugs[8..9].map(&:bug_id), opts).returns(test_rpc_bugs[8..9])

    test_cases = [
      # Case 1: Updated 4 bugs
      {:remaining_dirty_bugs => 6, :max_bugs_per_sync => 4},

      # Case 2: XMLRPC::Error, fetching 2 bugs failed so the dirty queue should
      # remain as it is
      {:remaining_dirty_bugs => 6, :max_bugs_per_sync => 2},

      # Case 3: Only updated 3 bug due to error, error will be logged
      # and the dirty bug queue will be cleared
      {:remaining_dirty_bugs => 2, :max_bugs_per_sync => 4},

      # Case 4: 2 dirty bugs left
      {:remaining_dirty_bugs => 0, :max_bugs_per_sync => 4},
    ]

    test_cases.each do |test_case|
      Settings.max_bugs_per_sync = test_case[:max_bugs_per_sync]

      # Make sure only 1 delayed job is enqueued
      assert_job_count(1)

      run_all_delayed_jobs
      assert_equal test_case[:remaining_dirty_bugs], DirtyBug.count
    end

    # Make sure the job is not rerun
    assert_job_count(0)
  end

  def assert_job_count(number)
    job = Delayed::Job.where('handler like ?', '%Bugzilla::UpdateDirtyBugsJob%')
    assert_equal number, job.count
  end

  def prepare_dirty_bugs(bugs)
    num = 0
    test_rpc_bugs = []
    bugs.each do |bug|
      num += 1
      DirtyBug.mark_as_dirty!(bug.id)
      test_rpc_bugs << to_test_rpc_bug(bug, bug.last_updated + num.hour)
    end
    test_rpc_bugs
  end

  def to_test_rpc_bug(bug, changed_date)
    Bugzilla::Rpc::RPCBug.new(
      'status'           => bug.bug_status,
      'id'               => bug.bug_id,
      'last_change_time' => changed_date,
      'component'        => bug.package.name)
  end
end
