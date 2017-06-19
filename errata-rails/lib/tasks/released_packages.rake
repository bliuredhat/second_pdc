namespace :released_packages do

  desc "Load released packages list for specified product version from text file"
  task :update_from_file => :environment do

    product_version_name = ENV['PRODUCT_VERSION'] or raise "Specify PRODUCT_VERSION=name on command line"
    product_version = ProductVersion.find_by_name(product_version_name) or raise "Can't find product version #{product_version_name}"
    package_list_file = ENV['PACKAGE_LIST'] or raise "Specify PACKAGE_LIST=filename on command line"
    username = ENV['WHO'] or raise 'Environment variable WHO not set'
    reason = ENV['REASON'] || 'Added via rake task'
    really_do_it = ENV['REALLY'] == '1'

    required_nvrs = File.read(package_list_file).chomp.split("\n").map(&:strip).map{|nvr| nvr.sub(/\.src\.rpm$/, '')}
    current_nvrs = product_version.released_brew_builds.pluck(:nvr)

    missing_nvrs = required_nvrs - current_nvrs
    extra_nvrs = current_nvrs - required_nvrs

    puts "Product Version: #{product_version.name}"
    puts "Input File: #{package_list_file}"
    puts "Current: #{current_nvrs.count}"
    puts "Required: #{required_nvrs.count}"
    puts "Adding: #{missing_nvrs.count}"
    puts "Removing: #{extra_nvrs.count}"
    puts "(DRY RUN MODE)" unless really_do_it
    ask_to_continue_or_cancel unless ENV['Y']

    (current_nvrs+required_nvrs).uniq.sort.each do |nvr|
      is_currently_loaded = current_nvrs.include?(nvr)
      should_be_loaded = required_nvrs.include?(nvr)
      if is_currently_loaded && should_be_loaded
        puts "  Leaving  #{product_version.name} #{nvr}" unless really_do_it
      elsif is_currently_loaded
        puts "- Removing #{product_version.name} #{nvr}"
        if really_do_it
          build = BrewBuild.find_by_nvr(nvr)
          ReleasedPackage.current.where(:product_version_id => product_version, :brew_build_id => build).update_all('current' => false)
        end
      elsif should_be_loaded
        puts "+ Adding   #{product_version.name} #{nvr}"
        if really_do_it
          old_count = ReleasedPackage.count
          begin
            update = ReleasedPackageUpdate.create!(
              :who => User.find_by_login_name!(username),
              :reason => reason,
              :user_input => {}
            )
            ReleasedPackage.make_released_packages_for_build(
              BrewBuild.make_from_rpc(nvr),
              product_version,
              update
            )
          rescue Timeout::Error
            puts "*** Timeout error for build #{nvr}, product_version #{product_version.name}"
          rescue => e
            puts "*** Error creating released package for #{nvr} #{product_version.name}: #{e.message}"
          end
          puts "*** No records created for #{nvr} #{product_version.name} (possibly due to no product listing in brew)" unless ReleasedPackage.count > old_count
        end
      end
    end

    puts "\n\nDry run only. Add REALLY=1 to command line to really do it." unless really_do_it

  end
end
