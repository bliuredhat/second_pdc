class StateTransition < ActiveRecord::Base
  serialize :roles, Array
  validates_presence_of :from, :to, :roles
  validates_uniqueness_of :from, :scope => :to
  validate :valid_states
  validate :valid_roles
  scope :from_state, lambda { |f| where(:from => f)}
  scope :user_selectable, :conditions => {:is_user_selectable => true}

  before_validation(:on => :create) do
    self.roles ||= []
    self.roles << 'secalert'
    self.roles << 'admin'
    self.roles.uniq!
  end

  # Get valid transitions from a state for a given user
  # Return empty relation if none available so that this
  # method can be chained
  def self.valid_transitions(current_state, user)
    return where('1 = 0') if user.is_readonly? || !user.enabled?
    transitions = StateTransition.from_state current_state
    transitions.select {|t| user.in_role?(*t.roles)}
    return where('1 = 0') if transitions.empty?
    transitions
  end

  # Need a special case for User.default_qa_user because it has enabled? false.
  # It's a workaround for the case where a PUSH_READY advisory is edited and
  # it has to be automatically bumped back down to REL_PREP. See Bug 875601.
  def performable_by?(user)
    (user == User.default_qa_user) || (!user.is_readonly? && user.enabled? && user.in_role?(*roles))
  end

  #
  # It's useful to know if it is a "moving forwards" transition
  # or a "moving backwards" transition.
  #
  # (Note that moving to DROPPED_NO_SHIP would be considered "forwards"
  # unless coming from SHIPPED_LIVE...)
  #
  def is_forwards?
    State.sort_order[to] > State.sort_order[from]
  end

  private
  def valid_states
    return unless to && from
    if from == to
      errors.add(:from, "From and to are the same state #{from}")
    end
    unless State.all_states.include?(to)
      errors.add(:to, "Invalid to state #{to}")
    end
    unless State.all_states.include?(from)
      errors.add(:from, "Invalid from state #{from}")
    end
  end

  def valid_roles
    # handled by validates_presence_of
    return if roles.blank?

    bad = roles.reject {|r| Role.exists?(:name => r)}
    unless bad.empty?
      errors.add(:roles, "Invalid roles: #{bad.join(', ')}")
    end
  end

end
