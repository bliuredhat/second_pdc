module ReleaseEngineeringHelper
  # returns create details (who, reason, when) of a brew build as an
  # array of 3 items that can be mapped to 'Added By', 'Reason', 'Created At'.
  def creation_details_for_build(build)
    # return record if there is one
    if build.user_id
      return [
        "#{build.realname} <#{build.login_name}>",
        build.reason,
        build.created_at.in_time_zone
      ]
    end

    # fallback: use errata if there is an assocation already
    associated_errata = build.released_errata
    if associated_errata
      return [
        'Added automatically',
        "Generated for advisory #{associated_errata.advisory_name}",
        associated_errata.actual_ship_date || '--'  # sometimes nil
      ]
    end
    # worst-case show unknown
    ['Unknown', '--', '--']
  end
end
