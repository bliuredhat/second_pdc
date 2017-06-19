module ReleaseHelper

  def link_to_state_machine_rule_set(rule_set, opts={})
    link_to(rule_set.name, {:controller=>:workflow_rules, :action=>:show, :id=>rule_set}, opts)
  end

end
