class BugsGuard < StateTransitionGuard
  def transition_ok?(errata)
    errata.bugs.any? || errata.jira_issues.any?
  end

  def ok_message(errata=nil)
    'Advisory has bugs assigned'
  end

  def failure_message(errata=nil)
    'Advisory has no Bugzilla bugs or JIRA issues'
  end
end
