class TpsRhnqaGuard < StateTransitionGuard
  def transition_ok?(errata)
    errata.tpsrhnqa_finished?
  end

  def ok_message(errata=nil)
    'TPS RHNQA complete'
  end

  def failure_message(errata=nil)
    return info_message(errata) unless self.mandatory?
    "Must complete TPS RHNQA"
  end

  def info_message(errata=nil)
    'TPS RHNQA not complete'
  end

  def test_type
    'tps'
  end
end
