class UpdateBadRuleSetTestRequirements < ActiveRecord::Migration
  def up
    StateMachineRuleSet.transaction do

      StateMachineRuleSet.pluck('id').each do |rule_set_id|

        begin
          rule_set = StateMachineRuleSet.find(rule_set_id)
          current_reqs = rule_set.test_requirements
        rescue ActiveRecord::SerializationTypeMismatch => error
          # If we have unparseable yaml then we may not be able to load the active
          # record object without throwing an ActiveRecord::SerializationTypeMismatch exception.
          # Clear the field out entirely using update_all so we don't try to instantiate any
          # ActiveRecord objects.
          puts "Clearing bad yaml for #{rule_set_id}!"
          StateMachineRuleSet.where(:id => rule_set_id).update_all(:test_requirements => nil)
          retry
        end

        fixed_reqs = get_fixed_test_requirements(rule_set)

        display_reqs = lambda do |r|
          case r when Set
            r.to_a.sort_by(&:downcase).join(" ")
          else
            # Rails returns a string in some cases
            r.inspect
          end
        end

        if fixed_reqs == current_reqs
          puts "#{rule_set.id} #{rule_set.name}: no change"
        else
          rule_set.update_attributes(:test_requirements => fixed_reqs)
          puts "#{rule_set.id} #{rule_set.name}: updated\n  old: #{display_reqs[current_reqs]}\n  new: #{display_reqs[fixed_reqs]}"
        end

      end
    end
  end

  def down
    # Do nothing
  end

  def get_fixed_test_requirements(rule_set)

    # Get the non transition guard items from TEST_REQS_DATA below
    if (data = TEST_REQS_DATA.fetch(rule_set.id, [])).empty?
       Rails.logger.warn "No data found for #{rule_set.id}!"
    end

    # Get the items derived from the transition guards
    # (Somewhat pointless, see BZ#1300514, but that's what we do)
    ( rule_set.state_transition_guards.map(&:test_type).uniq + data ).to_set
  end

  # This data includes just the test_requirements items that are *not* based on an
  # associated state transition guard.
  # Generated with:
  # puts StateMachineRuleSet.all.map{|s| "[#{s.id}, %w[ #{(s.test_requirements.to_a - s.state_transition_guards.map(&:test_type)).sort_by(&:downcase).join(" ")} ] ], # #{s.name}"}
  TEST_REQS_DATA = Hash[[
    [1, %w[ ccat ] ], # Default
    [2, %w[ ccat ] ], # Unrestricted
    [3, %w[ ccat ] ], # CDN Push Only
    [4, %w[ ccat covscan ] ], # Covscan
    [5, %w[ ccat covscan ] ], # RHEL 7 Beta
    [6, %w[ ccat ] ], # ABIDiff Pilot
    [7, %w[ ccat ] ], # Non-blocking TPS
    [8, %w[ ccat covscan ] ], # Covscan & ABIDiff
    [9, %w[ ccat covscan TpsDistQAManualOnly ] ], # Optional TPS DistQA
    [12, %w[ ccat covscan TpsDistQAManualOnly ] ], # Optional stage push for RHEL-6.8
    [13, %w[ ccat covscan TpsDistQAManualOnly ] ], # Optional stage push for RHEL-7.3
  ]]

end
