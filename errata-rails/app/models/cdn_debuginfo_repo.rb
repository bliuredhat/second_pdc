class CdnDebuginfoRepo < CdnRepo

  def type_matches_rpm?(brew_rpm)
    brew_rpm.is_debuginfo?
  end

end
