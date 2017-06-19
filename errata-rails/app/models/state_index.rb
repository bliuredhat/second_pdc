class StateIndex < ActiveRecord::Base
  belongs_to :errata
  has_many :comments,
  :order => 'created_at asc',
  :include => :who

  belongs_to :who,
  :class_name => "User"

  include Audited

  before_validation(:on => :create) do
    self.previous ||= errata.status
  end

  validate(:on => :create) do
    unless initial_index?
      validate_state_transition
      validate_transition_guards
    end
  end

  before_create do
    errata.is_valid = 1
    case current
    when State::NEW_FILES
      errata.rhnqa = 0
      errata.qa_complete = 0
    when State::QE
      if errata.requires_tps?
        errata.tps_run ||= TpsRun.create!(:errata => errata)
      end
    when State::REL_PREP, State::PUSH_READY
      errata.qa_complete = 1
    when State::SHIPPED_LIVE
      errata.qa_complete = 1
      errata.published = 1
    when State::DROPPED_NO_SHIP
      errata.qa_complete = 0
      errata.rhnqa = 0
      errata.is_valid = 0
    end
  end

  after_create do
    return if initial_index?
    errata.status = self.current
    errata.current_state_index = self
    errata.status_updated_at = self.created_at
    errata.save!
  end

  def initial_index?
    '' == previous && State::NEW_FILES == current
  end

  def current_index?
    self.id == self.errata.current_state_index_id
  end

  def prior_index
    StateIndex.where(:errata_id => self.errata, :current => self.previous).where("id < #{self.id}").order('id desc').first
  end

  def state_transition
    StateTransition.find_by_from_and_to previous, current
  end

  def transition_blockers
    t = state_transition
    rule_set = errata.state_machine_rule_set
    guard_types = ['block']
    guard_types << 'waive' unless who.in_role?('admin', 'secalert')
    guards = rule_set.guards_for_transition(t).where(:guard_type => guard_types)
    reasons = []
    guards.each do |g|
      unless g.transition_ok?(errata)
        reasons << g.failure_message(errata)
      end
    end
    reasons
  end

  def validate_transition_guards
    if errata.is_blocked?
      errors.add(:errata, 
                 "is blocked: #{errata.active_blocking_issue.blocking_role.name} - #{errata.active_blocking_issue.summary}")
    end

    blockers = transition_blockers
    blockers.each {|b| errors.add(:errata, b)}
  end

  def validate_state_transition
    unless previous == errata.status
      errors.add(:errata, "- Previous status not set to errata status: #{previous} vs #{errata.status}") && return
    end
    state_transition = StateTransition.find_by_from_and_to previous, current
    unless state_transition
      errors.add(:previous, "- Transition #{previous} => #{current} is invalid") && return
    end
    unless state_transition.performable_by? who
      errors.add(:who, "- #{who.to_s} does not have permission to perform #{previous} => #{current}")
    end
  end
end
