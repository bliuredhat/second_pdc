require 'test_helper'

class BugzillaSyncRecoveryTest < ActiveSupport::TestCase
  setup do
    @now = Time.now
    Time.stubs(:now).returns(@now)

    @from_date = @now - 5.days
    @to_date = @now

    Settings.bugzilla_sync_timestamp = @from_date
    Settings.bugzilla_sync_checkpoint = 1.week
  end

  test "recover from inaccessible bugs" do
    options = {
      'include_fields' => %w(id last_change_time),
      :f1 => 'delta_ts',
      :o1 => 'greaterthan',
      :v1 => @from_date.localtime.to_s(:db),
      :j_top => 'AND_G',
      :f2 => 'delta_ts',
      :o2 => 'lessthaneq',
      :v2 => @to_date.localtime.to_s(:db),
    }

    accesible_bugs = bz_bugs(Bug.limit(3), 1.hour)
    inaccessible_bugs = fake_new_bugs(2)

    bz_response = accesible_bugs + inaccessible_bugs
    Bugzilla::Rpc.any_instance.
      expects(:bug_search).with(options).
      returns('bugs' => bz_response)

    # Update filed bugs must mark all bugs retured as dirty
    Bugzilla::UpdateFiledBugsJob.new.perform
    assert_dirty_bugs_equal bz_response

    rpc_response = rpc_response_for_get(accesible_bugs, inaccessible_bugs)
    bug_ids = bz_response.map { |b| b['id'] }

    Bugzilla::Rpc::BugzillaConnection::AuthProxy.any_instance.
      expects(:get).
      with(:ids => bug_ids, :permissive => true,
           :include_fields => Bugzilla::Rpc::INCLUDE_FIELDS).
      returns(rpc_response)

    # ensure that dirty bug sync does not result in an error
    Bugzilla::UpdateDirtyBugsJob.new.perform
    assert_equal 0, DirtyBug.count
  end

  def assert_dirty_bugs_equal(expected_dirty_bugs)
    dirty_bug_ids = Array.wrap(expected_dirty_bugs).map { |b| b['id'] }
    # make sure the outdated bugs and new bugs are all marked as dirty
    actual_dirty_bugs = DirtyBug.where(:record_id => dirty_bug_ids)
    # make sure their initial status are nil
    refute actual_dirty_bugs.any? { |b| !b.status.nil? }
    assert_equal dirty_bug_ids.sort, actual_dirty_bugs.pluck(:record_id).sort
  end

  # fake rpc response from Bugzilla:: to the format that return by
  # Bugzilla::Rpc::BugzillaConnection::AuthProxy#get
  def rpc_response_for_get(bugs, faulty_bugs)
    faults = Array.wrap(faulty_bugs).map do |bug|
      id = bug['id']
      {
        "faultString" => "Bug #{id} does not exist.",
        "id"          => id,
        "faultCode"   => 101
      }
    end
    { "faults" => faults, "bugs" => bugs }
  end

  # convert to the format that return by Bugzilla api
  def bz_bugs(et_bugs, time_diff = 0)
    Array.wrap(et_bugs).reduce([]) do |bugs, et_bug|
      last_change = et_bug.last_updated + time_diff
      bugs << {
        'id' => et_bug.bug_id,
        'last_change_time' => xmlrpc_datetime(last_change)
      }
    end
  end

  def fake_new_bugs(number)
    new_bugs = []
    number.times do |id|
      new_bugs << {
        'id' => id + 99_999_000,
        'last_change_time' => xmlrpc_datetime(@now)
      }
    end
    new_bugs
  end

  def xmlrpc_datetime(date)
    utc = date.utc
    XMLRPC::DateTime.new(utc.year, utc.month, utc.day,
                         utc.hour, utc.min, utc.sec)
  end
end
