class ShipLiveGuard < StateTransitionGuard
  def transition_ok?(errata)
    blockers(errata).empty?
  end

  def ok_message(errata=nil)
    if errata
      nil
    else
      "No ship live blockers"
    end
  end

  def failure_message(errata=nil)
    if errata
      blockers(errata).join(', ')
    else
      "Still has ship live blockers"
    end
  end

  def test_type
    'mandatory'
  end

  private
  def blockers(errata)
    blockers = []
    if errata.publish_date.present? && errata.publish_date > Time.current
      blockers << "Can't publish before release date: #{errata.publish_date.strftime('%Y-%m-%d')}"
    end
    if errata.is_embargoed?
      blockers << "Advisory embargoed until: #{errata.embargo_date.strftime('%Y-%m-%d')}"
    end
    unless errata.is_signed?
      blockers << "Packages are not signed"
    end
    blockers
  end
end
