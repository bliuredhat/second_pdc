class CdnSourceRepo < CdnRepo

  def type_matches_rpm?(brew_rpm)
    brew_rpm.is_srpm?
  end

end
