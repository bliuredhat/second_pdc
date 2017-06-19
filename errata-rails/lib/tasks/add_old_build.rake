#
# Use this in the rare case where we want to add a build that is older
# than a build already shipped. See Bug 1193703.
#
# Example usage:
#  rake add_old_build ERRATA=19743 BUILD=rhn-upgrade-5.6.0.44-1.el5sat PV=RHEL-5-RHNSAT5.5
#
desc "add a build to an advisory without rpm version validation"
task :add_old_build => :environment do
  #
  # Will assume it's an rpm, not a non-rpm brew archive
  # See app/controllers/concerns/shared_api/errata_builds.rb
  #
  errata = Errata.find(ENV['ERRATA'])
  pv = ProductVersion.find_by_name!(ENV['PV'])
  build  = BrewBuild.make_from_rpc(ENV['BUILD'])

  # Don't want to bypass all the checks..
  raise "Record already exists!" if errata.errata_brew_mappings.for_rpms.exists?(
                                      :product_version_id => pv,
                                      :brew_build_id => build,
                                      :package_id => build.package)

  brew = Brew.get_connection
  raise "Not properly tagged!" unless brew.build_is_properly_tagged?(errata, pv, build)
  puts "Warning: Could not get product listings!" unless build.has_valid_listing?(pv)

  ActiveRecord::Base.transaction do
    ErrataBrewMapping.new(
      :errata => errata,
      :product_version => pv,
      :brew_build => build,
      :package => build.package,
      :brew_archive_type => nil
    ).tap do |m|
      # This allows the older build to be added.
      # Without it you would get something like:
      # "Build 'rhn-upgrade-5.7.0.22-1.el5sat' has newer or equal version of
      #   'rhn-upgrade-5.6.0.44-1.el5sat.src.rpm' in '5Server-Satellite' variant"
      m.skip_rpm_version_validation = true

      m.save!
    end
    puts "The build #{build} has been added to the advisory #{errata.advisory_name}"

    # Schedule rpmdiff runs
    RpmdiffRun.schedule_runs(errata.reload, User.current_user.login_name)
    puts "Rpmdiff runs have been scheduled for the advisory #{errata.advisory_name}"
  end

end
