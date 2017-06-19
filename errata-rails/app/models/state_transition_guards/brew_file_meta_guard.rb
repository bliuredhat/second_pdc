class BrewFileMetaGuard < StateTransitionGuard
  def transition_ok?(errata)
    errata.brew_files_missing_meta.empty?
  end

  def ok_message(errata=nil)
    # FIXME: the errata=nil case is serve for
    # represent workflow_rules pages.
    # another case for real workflow case
    if !errata || (errata.brew_files.any? &&
                  errata.brew_files.nonrpm.any?)
      return 'Attributes set on non-RPM files'
    elsif errata.brew_files.any? &&
        errata.brew_files.nonrpm.empty?
      return 'No non-RPM files in advisory'
    end
  end

  def failure_message(errata=nil)
    'Must set attributes on non-RPM files'
  end

  def test_type
    'mandatory'
  end
end
