require 'test_helper'

class UpdateFiledBugsJobTest < ActiveSupport::TestCase
  setup do
    @now = Time.now
    Time.stubs(:now).returns(@now)
  end

  test "perform" do
    from_date = @now - 5.days
    to_date = @now
    Settings.bugzilla_sync_timestamp = from_date
    Settings.bugzilla_sync_checkpoint = 1.week

    options = {
      'include_fields' => ['id','last_change_time'],
      :f1 => 'delta_ts',
      :o1 => 'greaterthan',
      :v1 => from_date.localtime.to_s(:db),
      :j_top => 'AND_G',
      :f2 => 'delta_ts',
      :o2 => 'lessthaneq',
      :v2 => to_date.localtime.to_s(:db),
    }

    bugs = Bug.limit(10)

    ok_bugs = to_bz_bugs(bugs[0..4])

    # add 1 hour to the last_updated time to make the bugs outdated
    outdated_bugs = to_bz_bugs(bugs[5..-1], 1.hour)

    # fake 2 new bugs from Bugzilla
    new_bugs = fake_new_bugs(5)

    expected_dirty_bugs = new_bugs + outdated_bugs
    all_bugs = ok_bugs + expected_dirty_bugs

    Bugzilla::Rpc.any_instance.expects(:bug_search).with(options).returns({'bugs' => all_bugs})

    # bugs 0..4 are up to date -> no update expected.
    # bugs 5..9 are outdated bug -> need to update
    # other bugs are fake new bug -> need to create

    Bugzilla::UpdateFiledBugsJob.new.perform

    assert_dirty_bugs_equal(expected_dirty_bugs)
  end

  def assert_dirty_bugs_equal(expected_dirty_bugs)
    dirty_bug_ids = expected_dirty_bugs.map{|b| b['id']}.sort

    # make sure the outdated bugs and new bugs are all marked as dirty
    actual_dirty_bugs = DirtyBug.where(:record_id => dirty_bug_ids)

    assert_equal dirty_bug_ids.sort, actual_dirty_bugs.pluck(:record_id).sort

    # make sure their initial status are nil
    refute actual_dirty_bugs.any?{|b| b.status != nil}
  end

  # convert to the format that return by Bugzilla api
  def to_bz_bugs(et_bugs, time_diff = 0)
    bz_bugs = []
    et_bugs.each do |et_bug|
      last_change = et_bug.last_updated + time_diff
      bz_bugs << {'id' => et_bug.bug_id, 'last_change_time' => to_xmlrpc_date(last_change)}
    end
    bz_bugs
  end

  def to_xmlrpc_date(date)
    # Simon Green advised bugzilla xmlrpc return utc time not est/us time
    utc_date = date.utc
    XMLRPC::DateTime.new(utc_date.year, utc_date.month, utc_date.day, utc_date.hour, utc_date.min, utc_date.sec)
  end

  def fake_new_bugs(number)
    new_bugs = []
    number.times do |id|
      new_bugs << {'id' => id + 99999000, 'last_change_time' => to_xmlrpc_date(@now)}
    end
    new_bugs
  end
end
