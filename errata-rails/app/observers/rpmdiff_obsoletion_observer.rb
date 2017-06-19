class RpmdiffObsoletionObserver < ErrataBuildMappingObserver
  observe ErrataBrewMapping, PdcErrataReleaseBuild

  # Obsoleting a mapping means some rpmdiff runs might have become obsolete.
  #
  # This is processed after commit, rather than after save, because the
  # result is affected by whether additional mappings have been added or
  # rpmdiff runs scheduled.  Therefore we should not obsolete runs until
  # all modifications for the current transaction have been made.
  def after_commit(mapping)
    if obsoleted?(mapping)
      RpmdiffRun.invalidate_obsolete_runs(mapping.errata)
    end
  end
end
