require 'test_helper'

class BugLogTest < ActiveSupport::TestCase
  test "basic logs" do
    bug = Bug.find(253788)
    assert_equal [], bug.logs

    with_time_passing(
      lambda { bug.unknown 'Unknown log level' },
      lambda { bug.debug 'Something about the bug...' },
      lambda { bug.info 'Doing something with bug...' },
      lambda { bug.warn 'Not looking good' },
      lambda { bug.error 'Something bad happened' },
      lambda { bug.fatal 'Crashed!' }
    )

    bug.reload
    logs = bug.logs.order('created_at DESC').to_a
    assert_equal %w{FATAL ERROR WARN INFO DEBUG UNKNOWN}, logs.map(&:severity)
    assert_equal <<-'eos'.strip_heredoc.split("\n"), logs.map(&:message)
      Crashed!
      Something bad happened
      Not looking good
      Doing something with bug...
      Something about the bug...
      Unknown log level
    eos
    assert_equal [bug].cycle(6).to_a, logs.map(&:bug)
    assert_equal [nil].cycle(6).to_a, logs.map(&:user)
  end

  test "log user" do
    bug = Bug.find(253788)
    assert_equal [], bug.logs

    bug.info 'hello from nobody'
    with_current_user(devel_user) { bug.info 'hello from devel' }
    bug.info 'hello from nobody again'

    bug.reload
    logs = bug.logs.order('id ASC').to_a
    assert_equal nil, logs[0].user
    assert_equal devel_user, logs[1].user
    assert_equal nil, logs[2].user
  end

  test "with error log" do
    bug = Bug.find(253788)
    assert_equal [], bug.logs

    Time.stubs(:now => 2.days.ago)
    bug.with_error_log('Something unexpectedly went wrong') do
      bug.info 'This block should not crash'
    end

    ex = nil
    begin
      bug.with_error_log('Something went wrong') do
        with_time_passing(
          lambda { bug.info 'About to crash...' },
          lambda { raise ArgumentError, "Oops!" }
        )
      end
    rescue ArgumentError => ex
    end

    assert_not_nil ex
    assert_equal 'Oops!', ex.message

    bug.reload
    logs = bug.logs.order('created_at ASC').to_a
    assert_equal 3, logs.length
    assert_equal 'INFO', logs.first.severity
    assert_equal 'This block should not crash', logs.first.message

    assert_equal 'INFO', logs.second.severity
    assert_equal 'About to crash...', logs.second.message

    assert_equal 'ERROR', logs.third.severity
    assert_equal 'Something went wrong: ArgumentError', logs.third.message
  end
end
