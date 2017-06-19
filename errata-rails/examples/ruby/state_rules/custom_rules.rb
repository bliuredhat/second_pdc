# Creates an unrestricted rule set. 
StateMachineRuleSet.create!(:name => 'Unrestricted', 
                            :description => 'Only has the mandatory Build and ShippedLive Guards')

# Creates a rule set that has info guards for tps and rpmdiff transitions
StateMachineRuleSet.transaction do
  r = StateMachineRuleSet.create!(:name => 'Info Transitions', 
                                  :description => 'Has Tps and RPMDiff guards, but are only informative. No documentation guard.')
  nq = StateTransition.find_by_from_and_to 'NEW_FILES', 'QE'
  RpmdiffGuard.create!(:state_machine_rule_set => r,
                       :guard_type => 'info',
                       :state_transition => nq)

  # QE to REL_PREP
  qr = StateTransition.find_by_from_and_to 'QE', 'REL_PREP'
  TpsGuard.create!(:state_machine_rule_set => r,
                   :guard_type => 'info',
                   :state_transition => qr)
  TpsRhnqaGuard.create!(:state_machine_rule_set => r,
                        :guard_type => 'info',
                        :state_transition => qr)
  RhnStageGuard.create!(:state_machine_rule_set => r,
                        :guard_type => 'info',
                        :state_transition => qr)


  rp = StateTransition.find_by_from_and_to 'REL_PREP', 'PUSH_READY'
  ps = StateTransition.find_by_from_and_to 'PUSH_READY', 'SHIPPED_LIVE'

  [rp,ps].each do |t|
    RhnStageGuard.create!(:state_machine_rule_set => r,
                          :guard_type => 'info',
                          :state_transition => t)

  end
end

# Clone the default RHEL process, add a blocking guard for ABI Diff
StateMachineRuleSet.transaction do
  default_rules = StateMachineRuleSet.find_by_name 'Default'
  abidiff_rules = default_rules.create_duplicate_rule_set!('ABI Diff',
                                                           'Same as Default rule set, but includes ABI Diff check NEW_FILES => QE')
  nq = StateTransition.find_by_from_and_to 'NEW_FILES', 'QE'
  AbidiffGuard.create!(:state_machine_rule_set => abidiff_rules,
                       :state_transition => nq)
end
