#
# Scripts for loading transition guards into rule sets
# (Will expand this later probably).
#
namespace :workflow_rules do

  #
  # Add two new transition guards related to dependencies. See Bug 803607
  #
  desc "load dependency transition guards"
  task :load_dep_guards => :environment do
    StateTransitionGuard.create_guard_helper(IsBlockedGuard)
    StateTransitionGuard.create_guard_helper(IsBlockingGuard)
  end


  #
  # Utility to display a rule set as a hash
  #
  desc "show rule set"
  task :show_rule_set => :environment do
    RULE_SET = ENV['RULE_SET'] || StateMachineRuleSet::DEFAULT_RULE_SET_ID
    pp StateMachineRuleSet.find(RULE_SET).to_hash
  end

  #
  # Adds a rule set which is same as default but with info only Covscan added
  #
  desc "add covscan pilot rule set"
  task :add_covscan_pilot_rule_set => :environment do
    # Create rule set as copy of the default one
    new_rule_set = StateMachineRuleSet.default_rule_set.create_duplicate_rule_set!(
      'Covscan Pilot',
      'Same as Default rule set but with a (non-blocking) Covscan test for each build added'
    )

    # Add External Tests transition guard to it
    StateTransitionGuard.create_guard_helper(ExternalTestsGuard, new_rule_set)

    # Want it to be info only for the pilot
    ExternalTestsGuard.last.update_attribute('guard_type','info')

    # Add covscan requirement to rule set
    new_rule_set.test_requirements << 'covscan'
    new_rule_set.save
  end

  desc "add hss internal product rule set"
  task :add_hss_internal_rule_set => :environment do
    # Create rule set as copy of the default one
    new_rule_set = StateMachineRuleSet.default_rule_set.create_duplicate_rule_set!(
      'CDN Push Only',
      "Same as Default rule set but with RHN related requirements removed"
    )

    # Remove the guards that relate to RHN
    new_rule_set.state_transition_guards = new_rule_set.state_transition_guards.reject { |state_transition_guard|
      [TpsRhnqaGuard, RhnStageGuard].include?(state_transition_guard.class)
    }

    # Remove the rhn test requirement
    new_rule_set.test_requirements = new_rule_set.test_requirements.reject { |test_requirement|
      test_requirement == 'rhn'
    }

    # Save it
    new_rule_set.save!
  end

  # Intended for use initially with RHEL-6 releases
  # (Since RHEL-6 release currently have Covscan enabled, will enable it for this also)
  desc "add rule sets that include abidiff"
  task :add_abidiff_pilot_rule_set => :environment do
    # Create new rule set as a copy of the default one
    new_rule_set = StateMachineRuleSet.default_rule_set.create_duplicate_rule_set!('ABIDiff Pilot',
      "Same as Default rule set but with non-blocking Covscan and non-blocking ABIDiff")

    # Add AbidiffGuard and ExternalTestsGuard guard to it
    StateTransitionGuard.create_guard_helper(ExternalTestsGuard, new_rule_set)
    StateTransitionGuard.create_guard_helper(AbidiffGuard, new_rule_set)

    # Set the new guards to info only initially, ie non-blocking
    ExternalTestsGuard.last.update_attribute('guard_type', 'info')
    AbidiffGuard.last.update_attribute('guard_type', 'info')

    # (Don't need to add abidiff here since it has its own guard and hence is implicitly included)
    new_rule_set.test_requirements << 'covscan'
    new_rule_set.save!
  end

  #
  # Rule set will be based on 'Optional TPS DistQA' but also not block if
  # advisory hasn't pushed to RHN stage. Actually make two, one with ABIDiff,
  # for RHEL-6.8, and one without, for RHEL-7.3.
  # See bug 1286713.
  #
  desc "Add rule sets that make RHN stage pushes optional"
  task :add_optional_rhn_stage_rule_set => :environment do
    copy_from = StateMachineRuleSet.find_by_name('Optional TPS DistQA')

    ActiveRecord::Base.transaction do

      new_1 = copy_from.create_duplicate_rule_set!(
        'Optional stage push for RHEL-6.8',
        'Optional stage push & TPS-DistQA, with Covscan & ABIDiff'
      ).tap do |rs|
        # Copy test requirements (they aren't copied automatically for some reason)
        rs.test_requirements = copy_from.test_requirements
        rs.save!

        # Make all the stage push guards non-blocking instead of blocking
        rs.state_transition_guards.where('type' => 'RhnStageGuard').update_all('guard_type' => 'info')

        # Add abidiff guard, then make it non-blocking
        StateTransitionGuard.create_guard_helper(AbidiffGuard, rs)
        rs.state_transition_guards.where('type' => 'AbidiffGuard').update_all('guard_type' => 'info')
      end

      new_2 = copy_from.create_duplicate_rule_set!(
        'Optional stage push for RHEL-7.3',
        'Optional stage push & TPS-DistQA, with Covscan'
      ).tap do |rs|
        # Copy test requirements (they aren't copied automatically for some reason)
        rs.test_requirements = copy_from.test_requirements
        rs.save!

        # Make the the stage push guard non-blocking instead of blocking
        rs.state_transition_guards.where('type' => 'RhnStageGuard').update_all('guard_type' => 'info')
      end


      # Take a look at them...
      pp new_1.to_hash
      puts "\n\n"
      pp new_2.to_hash
      puts "\n\n"

      # Apply to the release immediately (if it exists)
      if r1 = Release.find_by_name('RHEL-6.8.0')
        r1.update_attributes!(:state_machine_rule_set_id => new_1.id)
        puts "Updated RHEL-6.8.0."
      else
        puts "Release RHEL-6.8.0 not found."
      end

      if r2 = Release.find_by_name('RHEL-7.3.0')
        r2.update_attributes!(:state_machine_rule_set_id => new_2.id)
        puts "Updated RHEL-7.3.0."
      else
        puts "Release RHEL-7.3.0 not found."
      end

      puts "\n\n"
      raise "Rolling back. Set REALLY=1 to commit." unless ENV['REALLY'] == '1'

    end

  end

end
