namespace :ftp_exclusions do

  #
  # The aim is to prevent SRPMS being posted on ftp.redhat.com from
  # RHEL-5.7 and RHEL-6.2 onwards.
  #
  # (So this will need to run regularly each time a new RHEL release
  # is added, or until we actually update the code so this behaviour
  # becomes default).
  #
  # See https://bugzilla.redhat.com/show_bug.cgi?id=716503
  # and https://engineering.redhat.com/rt3/Ticket/Display.html?id=115015
  #
  desc "Create RHEL 5.7+ and 6.2+ ftp exclusions"
  task :create => :environment do

    DRY_RUN = true # change this to false to create records for real

    ##
    ## Old version, includes a lot of packages that aren't needed
    ##
    ## #
    ## # Get a list of packages that are redhat-release packages:
    ## #
    ## redhat_release_packages = Package.find(:all, :conditions => [
    ##   # Don't include redhat-release-notes
    ##   "name LIKE ? AND NOT name LIKE ?", 'redhat-release%', 'redhat-release-notes%'
    ## ]).reject! do |p|
    ##   # Remove packages with a 3 or a 4 in them, eg: redhat-release!4Desktop, redhat-release-4AS
    ##   p.name =~ /^redhat-release[!-][34]/
    ## end
    ##

    #
    # Use brew to determine which packages are current and relevant for the latest releases.
    #
    # Brew commands and output:
    #
    # $ brew list-pkgs --tag RHEL-6.2 | grep -i redhat-release
    # redhat-release-server   RHEL-6.0                                 dgregor
    # redhat-release-client   RHEL-6.0                                 dgregor
    # redhat-release-workstation RHEL-6.0                                 dgregor
    # redhat-release-computenode RHEL-6.0                                 dgregor
    #
    # $ brew list-pkgs --tag dist-5E-U7 | grep -i redhat-release
    # redhat-release          dist-5E-U6                               tkopecek
    # redhat-release-notes    dist-5E-Server-U1                        rlerch
    #
    #
    # Based on the results above, and disregarding redhat-release-notes, we get this:
    #
    # Actually for now, just going to do the RHEL-5 releases and worry about RHEL-6
    # later.
    #
    # Because ET does things a little differently, also need these guys:
    #   redhat-release!5Client
    #   redhat-release!5Server
    #   redhat-release-5Client
    #   redhat-release-5Server
    #
    redhat_release_packages = %w[
      redhat-release
      redhat-release!5Client
      redhat-release!5Server
      redhat-release-5Client
      redhat-release-5Server
    ].map{ |name| Package.find_by_name(name) }

    puts "\nRedhat Release Packages to consider\n=========================="
    redhat_release_packages.each { |p| puts p.name }


    ##
    ## Old version (actually still correct and good),
    ## but we are probably going to do things a different way
    ## so that newly created products get their ftp exclusion
    ## automatically added when required.
    ##
    ##
    ## #
    ## # Get the RHEL releases that require ftp exclusion
    ## #
    ## rhel_releases_for_exclusion = RhelRelease.all.select do |rhel_release|
    ##   if rhel_release.name =~ /RHEL-[56]$/
    ##     # Catch RHEL-5 and RHEL-6
    ##     true
    ##
    ##   elsif rhel_release.name =~ /RHEL-[56]\.(\d)/
    ##     # Catch RHEL-5.7.Z and RHEL-6.2.Z or higher
    ##     ($1 == "5" && $2 >= "7") || ($1 == "6" && $2 >= "2")
    ##
    ##   else
    ##     false
    ##
    ##   end
    ## end

    #
    # For now going to just do these ones:
    #  redhat-release              : RHEL-5
    #  redhat-release              : RHEL-5.7.Z
    #
    # See https://bugzilla.redhat.com/show_bug.cgi?id=716503#c10
    #
    # Need a way to have this apply to newly created product versions.
    # Worry about that later.
    #
    rhel_releases_for_exclusion = %w[ RHEL-5 RHEL-5.7.Z ].map{ |name| RhelRelease.find_by_name(name) }

    puts "\nRHEL Releases\n============="
    rhel_releases_for_exclusion.each{ |r| puts r.name }

    #
    # Get the product versions for each of the selected RHEL releases where
    # the product version name is the same as the RHEL release name.
    #
    # So for the RHEL release 'RHEL-5' we find the Product version 'RHEL-5'
    # and similar for RHEL-5.7.Z.
    #
    # So this is slightly pointless since we could have just hard-coded
    # these product_version names...
    #
    # (The reason it's like this is because
    # this code evolved from previous code where I was fetching *every*
    # product version instead of just the "matching" ones, ie this:
    # product_versions_for_exclusion =
    #   rhel_releases_for_exclusion.map{ |r| r.product_versions }.flatten
    #
    product_versions_for_exclusion = rhel_releases_for_exclusion.map{ |r| ProductVersion.find_by_name(r.name) }

    puts "\nProduct Versions\n============="
    product_versions_for_exclusion.each{ |pv| puts pv.name }

    #
    # Combine the releases and product versions together:
    #
    ftp_exclusions_required = []
    redhat_release_packages.each do |package|
      product_versions_for_exclusion.map do |product_version|
        ftp_exclusions_required << {
          :package            => package,
          :product_version    => product_version,

          # Let's add some extra fields so our code later looks more prettier
          :package_id           => package.id,
          :package_name         => package.name,

          :product_version_id   => product_version.id,
          :product_version_name => product_version.name,

          :product              => product_version.product,
          :product_id           => product_version.product.id,
          :product_name         => product_version.product.name,
        }
      end
    end

    puts "\nRequired ftp exclusion records\n============"
    ftp_exclusions_required.each { |r| puts "#{'%-35s' % r[:package_name]} : #{r[:product_version_name]}" }

    #
    # Now we are ready to actually do stuff...
    #
    puts "\nActions\n============="
    ftp_exclusions_required.each do |r|
      # The important things for a FtpExclusion record are the package and the product version
      puts "======================================================="
      puts "Package:         #{r[:package_name]} (id=#{r[:package_id]})"
      puts "Product Version: #{r[:product_version_name]} (id=#{r[:product_version_id]})"
      puts "Product:         #{r[:product_name]} (id=#{r[:product_id]})"

      # Does it exist already?
      ftp_exclusion = FtpExclusion.find_by_package_id_and_product_version_id(r[:package_id],r[:product_version_id])
      if (ftp_exclusion)
        puts "- already exists"

      else
        if DRY_RUN
          puts "*** DRY RUN ***"
        else
          FtpExclusion.create(
            :package_id         => r[:package_id],
            :product_version_id => r[:product_version_id],
            :product_id         => r[:product_id]
          )
        end

        puts "
          FtpExclusion.create(
            :package_id         => #{r[:package_id]},
            :product_version_id => #{r[:product_version_id]},
            :product_id         => #{r[:product_id]}
          )"

      end

      puts ""
    end

  end

  desc "List redhat-release ftp exclusions"
  task :list => :environment do
    FtpExclusion.all.select{ |e| e.package.name =~ /redhat-release/ }.each do |fe|
      puts "%-25s : %s" % [(fe.package.name if fe.package), (fe.product_version.name if fe.product_version)]
    end
  end

end
