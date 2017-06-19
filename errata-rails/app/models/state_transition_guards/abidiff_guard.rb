class AbidiffGuard < StateTransitionGuard
  def transition_ok?(errata)
    errata.abidiff_finished?
  end

  def ok_message(errata=nil)
    'Abidiff Complete'
  end

  def failure_message(errata=nil)
    "Must complete Abidiff"
  end

  # (Used by StateTransition.create_guard_helper)
  def self.recommended_transitions
    [
      StateTransition.find_by_from_and_to('NEW_FILES', 'QE')
    ]
  end
end
