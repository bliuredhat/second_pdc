class StagePushGuard < StateTransitionGuard
  def transition_ok?(errata)
    # HACK: allow text only errata to move to REL_PREP
    # See: https://engineering.redhat.com/rt/Ticket/Display.html?id=437045
    errata.text_only? || errata.stage_push_complete?
  end

  def ok_message(errata=nil)
    if errata
      return 'Staging push complete' if errata.supports_stage_push?
      return 'Staging push not required'
    end
    'Staging push complete or not required'
  end

  def failure_message(errata=nil)
    'Staging push jobs not complete'
  end

end
