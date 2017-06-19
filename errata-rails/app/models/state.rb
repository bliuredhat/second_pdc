module State
  NEW_FILES = 'NEW_FILES'
  QE = 'QE'
  REL_PREP = 'REL_PREP'
  PUSH_READY = 'PUSH_READY'
  IN_PUSH = 'IN_PUSH'
  DROPPED_NO_SHIP = 'DROPPED_NO_SHIP'
  SHIPPED_LIVE = 'SHIPPED_LIVE'

  ALL_STATES = [NEW_FILES, QE, REL_PREP, PUSH_READY, IN_PUSH, DROPPED_NO_SHIP, SHIPPED_LIVE]
  OPEN_STATES = [NEW_FILES, QE, REL_PREP, PUSH_READY]
  NOT_DROPPED_STATES = ALL_STATES.reject { |s| s == DROPPED_NO_SHIP }

  STAGE_PUSH_STATES = [QE, REL_PREP, PUSH_READY, SHIPPED_LIVE]
  LIVE_PUSH_STATES = [PUSH_READY, IN_PUSH, SHIPPED_LIVE]

  # Deprecated
  def self.all_states; ALL_STATES; end
  def self.open_states; OPEN_STATES; end

  def self.nice_label(state, opts={})
    nice = state.to_s.gsub(/_/,' ')
    opts[:short] ? nice.sub(/ NO SHIP$/,'').sub(/ LIVE$/,'') : nice
  end

  def self.open_state?(state)
    return open_states.include?(state)
  end

  def self.get_transitions(user, errata, ui_select_only = true)
    state = errata.status
    transitions = StateTransition.valid_transitions(state, user)
    transitions = transitions.user_selectable if ui_select_only
    transitions = transitions.to_a.select do |t|
      StateIndex.new(:errata => errata,
                     :who =>  user,
                     :previous => t.from,
                     :current => t.to).valid?
    end
    transitions.map(&:to).sort
  end

  #
  # This returns a hash like this: {"SHIPPED_LIVE"=>5, "PUSH_READY"=>3, "NEW_FILES"=>0, "DROPPED_NO_SHIP"=>4, "REL_PREP"=>2, "QE"=>1}
  # Use it to sort, eg states.sort_by { |state| State.sort_order[state] }
  # The Hash.new..merge is so we don't throw exceptions for non-standard states.
  #
  def self.sort_order
    Hash.new{ |h, k| h[k] = -1 }.merge( Hash[*State.all_states.zip([*0...State.all_states.length]).flatten] )
  end

  def self.sort_sql
    "(CASE errata_main.status #{sort_order.map{ |state,order| "WHEN '#{state}' THEN #{order}" }.join(" ")} ELSE 0 END)"
  end

end
