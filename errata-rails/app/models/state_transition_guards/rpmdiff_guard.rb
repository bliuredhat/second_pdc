class RpmdiffGuard < StateTransitionGuard
  def transition_ok?(errata)
    errata.rpmdiff_finished?
  end

  def ok_message(errata=nil)
    (!errata || errata.requires_rpmdiff?) \
      ? 'RPMDiff Complete' \
      : 'RPMDiff is not required'
  end

  def failure_message(errata=nil)
    return info_message(errata) unless mandatory?
    "Must complete RPMDiff"
  end

  def info_message(errata=nil)
    "RPMDiff is not complete"
  end
end
