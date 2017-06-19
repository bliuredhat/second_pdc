#
# This should prevent an advisory being moved to PUSH_READY
# when it has dependencies that are not yet SHIPPED_LIVE or
# in PUSH_READY.
#
class IsBlockedGuard < StateTransitionGuard
  include BlockingListHelper

  #
  # Define the transitions here, even though this doesn't actually
  # do anything.  Will use it in lib/tasks/load_workflow_rules.rake
  # when creating the transition guard records.
  #
  def self.recommended_transitions
    [
      # Going forward from REL_PREP to PUSH_READY
      StateTransition.find_by_from_and_to('REL_PREP', 'PUSH_READY'),
    ]
  end

  #
  # Can't move to PUSH_READY or SHIPPED_LIVE if
  # we are blocked by any other advisory.
  #
  def transition_ok?(errata)
    errata.currently_blocked_by.empty?
  end

  def ok_message(errata=nil)
    if errata && errata.possibly_blocked_by.empty?
      "No dependencies hence is not blocked."

    elsif errata
      "Not blocked by its dependencies (#{blocking_list_helper(errata.possibly_blocked_by)})."

    else
      "Not blocked by any dependencies."

    end
  end

  def failure_message(errata=nil)
    if errata
      "Can't move to PUSH_READY because it is blocked by #{blocking_list_helper(errata.currently_blocked_by)}."

    else
      "Can't move to PUSH_READY because it is blocked by its dependencies."

    end
  end

  def test_type
    'mandatory'
  end

end
