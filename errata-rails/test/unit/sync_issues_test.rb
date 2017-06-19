require 'test_helper'

class SyncIssuesTest < ActiveSupport::TestCase
  include SyncIssues
  setup do
    # Wipe out nsec in the time since YAML serialized to DB can't store
    # that precision. (Actually a no-op on ruby < 2 since times don't
    # store nsec there anyway.)
    @now = Time.zone.now.change(:nsec => 0)

  end

  test "set single checkpoint when sync date range is small" do
    start_from =  @now - 10.days
    Settings.sync_issues_checkpoint = 2.weeks

    loop_count = 0
    with_checkpoints(:sync_issues, start_from, @now, MockLogger) do |from_date, to_date|
      assert_equal start_from, from_date
      assert_equal to_date, @now
      loop_count +=1
    end

    # Make sure it only loops once.
    assert_equal 1, loop_count
    assert_equal @now, Settings.sync_issues_timestamp
  end

  test "set multiple checkpoints when sync date range is massive" do
    start_from = @now - 25.days
    Settings.sync_issues_checkpoint = 1.week
    Settings.sync_issues_timestamp = start_from

    date_ranges = [
      {:from => start_from, :to => (@now - 18.days)},
      {:from => (@now - 18.days), :to => (@now - 11.days)},
      {:from => (@now - 11.days), :to => (@now - 4.days)},
      {:from => (@now - 4.days),  :to => @now}
    ]

    loop_count = 0
    with_checkpoints(:sync_issues, start_from, @now, MockLogger) do |from_date, to_date|
      # current checkpoint
      assert_equal date_ranges[loop_count][:from], Settings.sync_issues_timestamp

      # current date range
      assert_equal date_ranges[loop_count][:from], from_date
      assert_equal date_ranges[loop_count][:to], to_date
      loop_count += 1
    end

    assert_equal @now, Settings.sync_issues_timestamp
  end

  test "resume to the last checkpoint after error occurred" do
    start_from = @now - 25.days
    Settings.sync_issues_checkpoint = 1.week
    Settings.sync_issues_timestamp = start_from

    date_ranges = [
      {:from => start_from, :to => (@now - 18.days)},
      {:from => (@now - 18.days), :to => (@now - 11.days)},
      # error occur here
      {:from => (@now - 11.days), :to => (@now - 4.days)},
      # resume from here
      {:from => (@now - 11.days), :to => (@now - 4.days)},
      {:from => (@now - 4.days),  :to => @now}
    ]

    loop_count = 0
    while(loop_count < 5)
      begin
        start_from = Settings.sync_issues_timestamp
        with_checkpoints(:sync_issues, start_from, @now, MockLogger) do |from_date, to_date|
          raise StandardError, "Failed intentionally" if loop_count == 2
          # current date range
          assert_equal date_ranges[loop_count][:from], from_date
          assert_equal date_ranges[loop_count][:to], to_date
          loop_count += 1
        end
      rescue Exception => ex
        loop_count += 1
      end
    end

    assert_equal @now, Settings.sync_issues_timestamp
  end
end