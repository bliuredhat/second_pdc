#
# This should prevent an advisory being moved out of SHIPPED_LIVE
# or PUSH_READY when it is blocking other advisories that are currently
# in SHIPPED_LIVE or PUSH_READY.
#
class IsBlockingGuard < StateTransitionGuard
  include BlockingListHelper

  #
  # Define the transitions here, even though this doesn't actually
  # do anything.  Will use it in lib/tasks/load_workflow_rules.rake
  # when creating the transition guard records.
  #
  def self.recommended_transitions
    [
      # Going back from PUSH_READY to REL_PREP
      StateTransition.find_by_from_and_to('PUSH_READY',  'REL_PREP'),
      # Going back from SHIPPED_LIVE to REL_PREP
      StateTransition.find_by_from_and_to('SHIPPED_LIVE','REL_PREP'),
    ]
  end

  #
  # If we are SHIPPED_LIVE or PUSH_READY, and we are a blocker for other
  # advisories that are also SHIPPED_LIVE or PUSH_READY, then we should
  # not be able to move back to REL_PREP, since that would violate
  # the dependency rules for the other advisory.
  #
  def transition_ok?(errata)
    errata.would_block_if_withdrawn.empty?
  end

  def ok_message(errata=nil)
    if errata && errata.possibly_blocks.empty?
      "Could move back from #{self.state_transition.from} since it has no dependent advisories."

    elsif errata
      "Could move back from #{self.state_transition.from} without affecting its dependent advisories: #{blocking_list_helper(errata.possibly_blocks)}."

    else
      "Could move from #{self.state_transition.from} without affecting any dependent advisories."

    end
  end

  def failure_message(errata=nil)
    if errata
      "Can't move back from #{self.state_transition.from} since it would break the dependency rules for: #{blocking_list_helper(errata.would_block_if_withdrawn)}."

    else
      "Can't move back from #{self.state_transition.from} since it would break the dependency rules for one or more dependent advisories."

    end
  end

  def test_type
    'mandatory'
  end

end
