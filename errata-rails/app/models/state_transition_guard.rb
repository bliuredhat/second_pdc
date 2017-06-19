class StateTransitionGuard < ActiveRecord::Base
  belongs_to :state_transition
  belongs_to :state_machine_rule_set

  validates_presence_of  :guard_type, :state_transition
  validates_inclusion_of :guard_type, :in => ['block', 'waive', 'info']

  validate do
    errors.add(:state_machine_rule_set, "is locked") if self.state_machine_rule_set.is_locked?
  end

  after_create do
    self.state_machine_rule_set.test_requirements << self.test_type
    self.state_machine_rule_set.save
  end

  scope :blocking, where(:guard_type => 'block')
  scope :informative, where(:guard_type => 'info')
  scope :waivable, where(:guard_type => 'waive')

  def transition_ok?(errata)
    false
  end

  def status_icon(errata)
    if transition_ok?(errata)
      :ok
    else
      guard_type.to_sym
    end
  end

  def mandatory?
    guard_type != "info"
  end

  def ok_message(errata=nil)
    raise 'ok_message should be defined in a subclass'
  end

  def failure_message(errata=nil)
    raise 'failure_message should be defined in a subclass'
  end

  def message(errata=nil)
    return ok_message(errata) if transition_ok?(errata)
    message = failure_message(errata)
    message += ' (optional)' unless mandatory?
    message
  end

  def test_type
    self.class.to_s.gsub('Guard','').downcase
  end


  #
  # Am using this in lib/tasks/load_workflow_rules
  # and in test/unit/state_test.rb
  #
  # It's for creating a new transition guard.
  #
  def self.create_guard_helper(guard_type, rule_set=StateMachineRuleSet.default_rule_set)
    # I defined the transitions in the class, so use those
    guard_type.recommended_transitions.each do |transition|
      guard_type.create!(:state_machine_rule_set => rule_set, :state_transition => transition)
    end
  end

end
