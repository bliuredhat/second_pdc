class ActiveSupport::TestCase

  # Execute a block and return all log messages generated within the block.
  #
  # Messages passed to any Logger instance are captured.
  #
  # Returns an array of hashes, each containing the log parameters:
  #   :severity
  #   :timestamp
  #   :progname
  #   :msg
  #   :caller
  #
  def capture_logs(&block)
    logs = []
    real_method = Logger.instance_method(:format_message)
    ActiveSupport::TestCase.with_replaced_method(
      ObjectSpace.each_object(Logger),
      :format_message,
      lambda do |severity, timestamp, progname, msg|
        logs << {:severity => severity, :timestamp => timestamp, :progname => progname, :msg => msg.to_s,
          :logger => respond_to?(:name) ? name : nil,
          :caller => caller.drop_while{|loc| loc =~ /\/logger\.rb:\d+/}}
        real_method.bind(self).call(severity, timestamp, progname, msg)
      end,
      &block
    )
    logs
  end

  # Execute a block and generate a test failure if any log messages
  # with a severity greater than or equal to max_severity are produced within that block.
  #
  # If msg is provided, it is included within the failure message.
  #
  # Example:
  #
  #   with_no_logs_expected(Logger::Severity::WARN) do
  #     someobj.do_this!
  #     someobj.do_that!
  #   end  # test fails here if any warnings or errors were logged
  #
  def with_no_logs_expected(max_severity, msg = nil, &block)
    logs = capture_logs(&block)
    failures = logs.map do |log|
      severity_str = log[:severity]
      next unless Logger::Severity.const_get(severity_str) >= max_severity

      # give a handful of stack frames (no way to know how many are useful)
      bt = log[:caller][0..2].map{|s| "    at #{s}"}
      if bt.length < log[:caller].length
        bt << "    (...)"
      end

      "  #{severity_str}: #{log[:msg]}\n" + bt.join("\n")
    end.compact

    unless failures.empty?
      msg ||= 'Unexpected log messages'
      flunk( ([msg+':'] + failures).join("\n\n") )
    end
  end

  # Asserts that no error shall be logged during a test.
  #
  # This method accepts test functions or test classes as arguments.
  # If a test class is provided, the assertion applies to all test functions on that class.
  # If no argument is provided, the assertion applies to all test functions on the current class.
  #
  # Examples:
  #
  #   class PushJobTest < ActiveSupport::TestCase
  #     # any test function logging an error will fail
  #     assert_no_error_logs
  #
  #     ...
  #   end
  #
  #   class MyTest < ActiveSupport::TestCase
  #     test 'some thing' do
  #       ...
  #     end
  #
  #     test 'other thing' do
  #       ...
  #     end
  #
  #     assert_no_error_logs :test_some_thing, :test_other_thing
  #   end
  #
  # Sample output:
  #
  #   1) Failure:
  # test_Submit_to_Pub(PushJobTest) [/test/test_helper/logging.rb:59]:
  # Unexpected log messages occurred during execution of test_Submit_to_Pub:
  #
  #   ERROR: Unable to get a task id from Pub; submission failed
  #     at /home/rmcgover/src/errata-rails/app/models/push_job.rb:294:in `error'
  #     at /home/rmcgover/src/errata-rails/app/models/push_job.rb:148:in `mark_as_failed!'
  #     at /home/rmcgover/src/errata-rails/app/models/push_job.rb:109:in `create_pub_task'
  #     (...).
  #
  def self.assert_no_error_logs(*args)
    assert_no_logs(Logger::Severity::ERROR, *args)
  end

  # Like assert_no_error_logs, but also asserts that no warnings shall be logged.
  def self.assert_no_warning_logs(*args)
    assert_no_logs(Logger::Severity::WARN, *args)
  end

  private

  # Run block during test setup, or immediately if we're already within test setup.
  def self._in_setup(&block)
    if @@_in_setup > 0
      return block.call()
    end

    self.setup do
      @@_in_setup += 1
      begin
        block.call()
      ensure
        @@_in_setup -= 1
      end
    end
  end
  @@_in_setup = 0

  def self.assert_no_logs(severity, *args)
    if args.empty?
      args = [self]
    end

    # Delay the enumeration/replacement of test methods until setup phase.
    # If we do it now, we might miss test methods added later.
    _in_setup do
      args.flatten.each do |arg|
        if arg.kind_of?(String) || arg.kind_of?(Symbol)
          assert_no_logs_in_test(severity, arg.to_sym)
        elsif arg.kind_of?(Class)
          all_tests = arg.instance_methods.grep(/^test_/)
          assert_no_logs(severity, *all_tests) unless all_tests.empty?
        else
          raise ArgumentError, "invalid argument: #{arg.inspect}"
        end
      end
    end
  end

  # asserts that no log messages with severity are produced while executing the
  # test with name: test_name
  def self.assert_no_logs_in_test(severity, test_name)
    # sanitize
    test_name = test_name.to_s

    old_method_alias = "_assert_no_logs_#{severity}_target_#{test_name}".to_sym
    return if method_defined? old_method_alias

    # Internals:
    # stores the test_name in #{old_method_alias} as an alias
    # replaces the test_name with a new method that invokes the original wrapping it in
    # with_no_logs_expected

    test_name_sym = test_name.to_sym
    override_test_name = <<-eos_method.strip_heredoc
      alias #{old_method_alias} #{test_name_sym}

      def #{test_name}(*args, &block)
        msg =  "Unexpected log messages occurred during execution of #{test_name}".strip
        with_no_logs_expected(#{severity}, msg) do
          #{old_method_alias}(*args, &block)
        end
      end
    eos_method
    class_eval override_test_name
  end
end
