class RhnStageGuard < StateTransitionGuard
  def transition_ok?(errata)
    return true unless errata.supports_rhn_stage?
    errata.rhnqa?
  end

  def ok_message(errata=nil)
    errata.nil? || errata.supports_rhn_stage? ? 'Advisory on RHN Stage' : 'RHN Stage not used for this advisory'
  end

  def failure_message(errata=nil)
    return info_message(errata) unless mandatory?
    'Advisory must be up to date on RHN Stage'
  end

  def info_message(errata=nil)
    'Advisory is not up to date on RHN Stage'
  end

  def test_type
    'rhn'
  end
end
