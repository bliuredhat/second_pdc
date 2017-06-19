class RpmdiffReviewGuard < StateTransitionGuard
  def transition_ok?(errata)
    errata.rpmdiff_review_finished?
  end

  def ok_message(errata=nil)
    'No unapproved RPMDiff waivers'
  end

  def failure_message(errata=nil)
    if errata && errata.requires_rpmdiff_review?
      'RPMDiff waivers must be reviewed'
    else
      'RPMDiff waivers should be reviewed'
    end
  end
end
