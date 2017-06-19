class BugObserver < ActiveRecord::Observer
  observe Bug

  def after_update(bug)
    return unless bug.errata.any? && bug.package_id_changed?

    # Update advisory<->package association if needed
    old_package = bug.package_id_was
    bug.errata.each do |e|
      ReleaseComponent.unassign_from_advisory(e, [old_package])
      ReleaseComponent.assign_to_advisory(e)
    end
  end

  def after_save(bug)
    # mark the bug as clean
    bug.dirty_bugs.each(&:mark_as_clean)
  end
end
