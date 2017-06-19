namespace :external_tests do

  desc "add a test run (for testing)"
  task :add_run => :environment do
    errata = Errata.find(ENV['ID']||14337)
    errata.create_external_test_run_for(:covscan)
  end

  desc "add the transition guard"
  task :add_guard => :environment do
    # This will add to the default rule set
    # (Not sure yet what rule set it should actually on in prod)
    StateTransitionGuard.create_guard_helper(ExternalTestsGuard)

    # Also add this so the advisory requires covscan
    # (Slightly confusing since 'externaltests' will also
    # be in the set of test_requirements..)
    s = StateMachineRuleSet.default_rule_set
    s.test_requirements << 'covscan'
    s.save
  end

end
