module ExternalTests
  extend ActiveSupport::Concern

  # This (potentially) includes test runs for different external test systems.
  included do
    has_many :external_test_runs, :include => :external_test_type
  end


  #
  # Determine if a particular external test is applicable to this advisory.
  # Use the state machine rule set for the advisory to decide.
  #
  # Can pass in either the name of an ExternalTestType as a string
  # or an ExternalTestType object.
  #
  # There is a special case for text only advisories which do not do any
  # external tests, even if they are specified in the advisory's state machine
  # rule set.
  #
  def requires_external_test?(test_type)
    return false if text_only?

    test_type = ExternalTestType.get(test_type)
    return false unless test_type

    self.state_machine_rule_set.test_requirements.include?(test_type.toplevel_name)
  end

  #
  # Returns a list of external tests (ExternalTestType objects) that are required for
  # this advisory, filtered by the given test types.
  #
  def external_tests_required(test_types = nil)
    test_types = ExternalTestType.active unless test_types
    test_types.select { |test_type| requires_external_test?(test_type) }
  end

  #
  # Returns all the external test runs for a particular test type including non-current ones.
  #
  def external_test_runs_for(test_type)
    external_test_runs.where(:external_test_type_id => ExternalTestType.get(test_type))
  end

  #
  # Returns all the current external test runs for a particular test.
  #
  def current_external_test_runs_for(test_type)
    external_test_runs_for(test_type).current
  end

  #
  # Determine if the test runs have passed (or been waived) for a particular test.
  #
  def external_test_runs_passed_for?(test_type)
    test_types = ExternalTestType.get(test_type).with_related_types
    current_runs = current_external_test_runs_for(test_types)
    current_runs.any? && current_runs.all?(&:passed_ok?)
  end

  #
  # Returns the test types that are currently blocking, ie not passed or waived,
  # only considering the given test types.
  #
  def external_tests_blocking(test_types = nil)
    external_tests_required(test_types).select { |test_type| !external_test_runs_passed_for?(test_type) }
  end

  #
  # Determine if the test runs have passed (or been waived) for all the required tests
  # of the given type(s).
  #
  def all_external_test_runs_passed?(test_types = nil)
    external_tests_blocking(test_types).empty?
  end

  #
  # Returns the test types required for the given transition
  # (which is actually criteria applied on state_transitions).
  #
  def required_external_tests_for_transition(transition_cond)
    guards = state_machine_rule_set.
      state_transition_guards.
      joins(:state_transition).
      where(:type => ExternalTestsGuard).
      where(:state_transitions => transition_cond)

    mappings = ExternalTestsGuardTestType.where(:external_tests_guard_id => guards)
    test_types = ExternalTestType.where(:id => mappings.pluck('distinct external_test_type_id'))

    test_types.select{ |type| requires_external_test?(type) }
  end

  #
  # True if (any) external tests must be completed before moving to QE state
  #
  def requires_external_tests_for_qe?
    required_external_tests_for_transition(:from => 'NEW_FILES', :to => 'QE').any?
  end

  #
  # Create a test run.
  #
  def create_external_test_run_for(test_type, attributes={})
    ExternalTestRun.create({:errata_id=>self.id, :external_test_type_id=>ExternalTestType.get(test_type).id}.merge(attributes))
  end
end
