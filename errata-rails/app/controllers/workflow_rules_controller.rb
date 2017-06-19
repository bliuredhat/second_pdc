#
# (Called this WorkflowRulesController instead of StateMachineRuleSetController)
#
# This will be read-only initially.
#
class WorkflowRulesController < ApplicationController
  before_filter :find_errata, :only => :for_advisory

  def index
    @rule_sets = StateMachineRuleSet.all
    set_page_title 'Workflow Rule Sets'
  end

  def show
    @rule_set = StateMachineRuleSet.find(params[:id])
    @guards = sorted_guards
    set_page_title "Rules for '#{@rule_set.name}'"
  end

  def for_advisory
    @rule_set = @errata.state_machine_rule_set
    @guards = sorted_guards
    @show_all = params[:show_all].present?

    # By default show just the guards for the current state
    @guards = @guards.select { |guard| guard.state_transition.from == @errata.status } unless @show_all

    set_page_title "#{@errata.fulladvisory} workflow status"
  end

  private

  def sorted_guards(rule_set=nil)
    # Need to carefully sort them by transition so the grouping
    # works. After that it doesn't matter much, but might as well
    # make it explicit.
    # Put the "moving backwards" transitions at the end to make it
    # slightly easier follow the typical forward flow.
    (rule_set||@rule_set).state_transition_guards.sort_by { |guard|
      [
        (guard.state_transition.is_forwards? ? 0 : 1),
        State.sort_order[guard.state_transition.from],
        State.sort_order[guard.state_transition.to],
        guard.guard_type,
        guard.test_type,
        guard.id,
      ]
    }
  end

end
