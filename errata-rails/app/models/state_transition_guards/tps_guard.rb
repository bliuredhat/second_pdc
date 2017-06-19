class TpsGuard < StateTransitionGuard
  def transition_ok?(errata)
    errata.tps_finished?
  end

  def ok_message(errata=nil)
    'TPS complete'
  end

  def failure_message(errata=nil)
    return info_message(errata) unless self.mandatory?
    "Must complete TPS"
  end

  def info_message(errata=nil)
    'TPS not complete'
  end
end
