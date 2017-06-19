require 'test_helper'

class LogFilePermissionsTest < ActiveSupport::TestCase

  test 'log files are group writable' do
    logger_name = "permission_test"
    logger_file = Rails.root.join("log", "#{logger_name}.log").to_s

    File.delete(logger_file) if File.exist?(logger_file)

    ErrataLogger.new(logger_name)

    # (Compare octal strings for readability)
    assert_equal('100664', '%o' % File.stat(logger_file).mode)
  end
end
