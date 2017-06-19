class ExternalTestsGuard < StateTransitionGuard
  has_many :external_tests_guard_test_types
  has_many :external_test_types,
           :through => :external_tests_guard_test_types

  def transition_ok?(errata)
    errata.all_external_test_runs_passed?(external_test_types)
  end

  def ok_message(errata=nil)
    if errata
      tests_required = errata.external_tests_required(external_test_types)
      if tests_required.empty?
        "No external tests required"
      else
        "Passed tests for #{tests_required.map(&:tab_name).join(", ")}"
      end
    else
      "Passed any required external tests"
    end
  end

  def failure_message(errata=nil)
    if errata
      "Advisory has not yet passed tests for: #{errata.external_tests_blocking(external_test_types).map(&:tab_name).join(", ")}"
    else
      "Advisory has not passed all external tests"
    end
  end

  #
  # Define the transitions here, even though this doesn't actually
  # do anything.  Will use it in lib/tasks/load_workflow_rules.rake
  # when creating the transition guard records.
  #
  def self.recommended_transitions
    [
      StateTransition.find_by_from_and_to('NEW_FILES',  'QE')
    ]
  end
end
