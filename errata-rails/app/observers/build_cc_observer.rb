class BuildCcObserver < ActiveRecord::Observer
  observe ErrataBrewMapping, PdcErrataReleaseBuild

  def after_create(mapping)
    errata = mapping.errata
    user = User.current_user

    return unless \
      user &&
      user.enabled? &&
      user.receives_mail? &&
      user.in_role?('errata') &&
      !(user.preferences && user.preferences[:omit_cc_on_add_build]) &&
      errata.cc_list.where(:who_id => user).empty?

    Rails.logger.info "Adding #{user.login_name} to CC on #{errata.advisory_name} - user added build #{mapping.brew_build.nvr}"
    CarbonCopy.create!(:errata => errata, :who => user)
  end
end
