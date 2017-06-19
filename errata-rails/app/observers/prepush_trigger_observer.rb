class PrepushTriggerObserver < ActiveRecord::Observer
  observe Bug, BrewBuild

  def after_update(record)
    return after_update_brew_build(record) if record.kind_of?(BrewBuild)
    return after_update_bug(record) if record.kind_of?(Bug)
  end

  def after_update_brew_build(bb)
    # builds need to be signed and in one of the advisories in REL_PREP
    return unless bb.signed_rpms_written_changed? &&
                  bb.signed_rpms_written? &&
                  bb.errata.map(&:status).include?("REL_PREP")

    # Build has just become signed. This might trigger pre-push of associated errata,
    # so run pre-push job now rather than at the next poll interval.
    Rails.logger.debug "pre-push: build #{bb.nvr} just signed, checking errata"
    Push::PrepushTriggerJob.run_soon
  end

  def after_update_bug(bug)
    # same as builds, pre-push condition is that the advisory is in REL_PREP
    return unless bug.errata.map(&:status).include?("REL_PREP")

    # If this bug modification might have changed the embargoed_bugs of any errata,
    # bring forward the pre-push trigger job.
    #
    # Note this is a compromise. It's too expensive to queue pre-push trigger job every
    # time any bug updates, but also too expensive to calculate accurately here whether
    # the job needs to be triggered. So the main goal of this is just to filter out
    # the majority of the bug updates which have no impact on embargoed bugs.
    changed = bug.changed_attributes

    # If bug became public, or was moved out of Security Response product, or was moved
    # out of "vulnerability" component, then it is not embargoed and might possibly have
    # been previously embargoed, so check if anything is newly eligible for pre-push.
    if (changed.has_key?('is_private') && !bug.is_private?) ||
      (changed.has_key?('is_security') && !bug.is_security?) ||
      (changed.has_key?('package_id') && bug.package.name != 'vulnerability')
      Rails.logger.debug "pre-push: bug #{bug.id} maybe became unembargoed, trigger"
      Push::PrepushTriggerJob.run_soon
    end
  end
end
