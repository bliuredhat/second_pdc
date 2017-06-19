class StateMachineRuleSet < ActiveRecord::Base
  serialize :test_requirements, Set

  has_many :state_transition_guards,
    :dependent => :delete_all
  has_many :products
  has_many :releases

  validates_presence_of :name, :description
  validates_uniqueness_of :name

  has_many :tps_guards
  has_many :tps_rhnqa_guards

  before_validation(:on => :create) do
    self.test_requirements ||= Set.new
  end

  before_update do
    return if self.is_locked? and self.is_locked_changed?
    raise "Rule set is locked!" if self.is_locked?
  end

  after_create do
    # Mandatory check for files in NEW_FILES => QE unless is a text_only advisory
    nq = StateTransition.find_by_from_and_to 'NEW_FILES', 'QE'
    qr = StateTransition.find_by_from_and_to 'QE', 'REL_PREP'
    rp = StateTransition.find_by_from_and_to 'REL_PREP', 'PUSH_READY'
    pi = StateTransition.find_by_from_and_to 'PUSH_READY', 'IN_PUSH'

    BuildGuard.create!(:state_machine_rule_set => self,
                       :state_transition => nq)

    # Mandatory check for channel and repo to text_only advisory
    [qr, rp, pi].each do |t|
      TextOnlyAdvisoryGuard.create!(:state_machine_rule_set => self,
                                    :state_transition => t)
    end

    # Mandatory checks for embargo dates and package signing
    [rp,pi].each do |t|
      ShipLiveGuard.create!(:state_machine_rule_set => self,
                            :state_transition => t)
    end
  end

  DEFAULT_RULE_SET_ID = 1
  def self.default_rule_set
    self.find(DEFAULT_RULE_SET_ID)
  end

  def create_duplicate_rule_set!(dup_name = nil, dup_desc = nil)
    dup_name ||= "Duplicate of #{self.name}"
    dup_desc ||= "Duplicate of #{self.description}"
    dup = nil
    transaction do
      dup = StateMachineRuleSet.create!(:name => dup_name,
                                        :description => dup_desc,
                                        :test_requirements => self.test_requirements)
      self.state_transition_guards.each do |g|
        next if [ShipLiveGuard, BuildGuard, TextOnlyAdvisoryGuard].include?(g.class)
        g.class.create!(:state_machine_rule_set => dup,
                        :state_transition => g.state_transition,
                        :guard_type => g.guard_type)
      end
    end
    dup
  end

  def test_requirements_text
    self.test_requirements.map(&:to_s).map(&:titleize).sort.join(', ')
  end

  def guards_for_transition(state_transition)
    self.state_transition_guards.where(:state_transition_id => state_transition)
  end

  def label
    "#{name} - #{description}"
  end

  # Convenience method for debugging
  def to_hash
    {
      :name => name,
      :description => description,
      :test_requirements => test_requirements.to_a,
      :state_transition_guards => state_transition_guards.order(:state_transition_id).map do |g|
        {
          :id => g.id,
          :state_transition => {
            :from => g.state_transition.from,
            :to => g.state_transition.to
          },
          :guard_type => g.guard_type,
          :test_type => g.test_type,
          :failure_message => g.failure_message
        }
      end
    }
  end

  # Get all guards for this state that require to move to the next state
  def guards_in_state(state, guard_type = :state_transition)
    self.
      send("#{guard_type}_guards").
      includes(:state_transition).
      where(:state_transitions => {:from => state}).
      select{|g| g.state_transition.is_forwards?}
  end
end
