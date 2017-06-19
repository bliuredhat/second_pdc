require 'json'

namespace :pdc_released_packages do

  desc "Create pdc released packages from mapping released packages"
  task :create_pdc_released_packages => :environment do

    # Here the mapping list file can be a json file in following format.
    # {
    #   "mappings": [
    #     {
    #       "product_version": "RHEL-7-CEPH-2",
    #       "variant": "7Server-RH7-CEPH-MON-2",
    #       "pdc_release": "ceph-2.1-updates@rhel-7",
    #       "pdc_variant": "MON"
    #     },
    #     {
    #       "product_version": "RHEL-7-CEPH-2",
    #       "variant": "7Server-RH7-CEPH-OSD-2",
    #       "pdc_release": "ceph-2.1-updates@rhel-7",
    #       "pdc_variant": "OSD"
    #     }
    #     ...
    #   ]
    # }
    mappings_file = ENV['MAPPINGS_LIST'] or raise "Specify MAPPINGS_LIST=filename on command line"
    username = ENV['WHO'] or raise 'Environment variable WHO not set'
    reason = ENV['REASON'] || "Copied legacy released packages to PDC released packages using mappings in #{mappings_file} using rake task."
    really_do_it = ENV['REALLY'] == '1'

    puts "Input File: #{mappings_file}"
    puts "(DRY RUN MODE)" unless really_do_it
    ask_to_continue_or_cancel unless ENV['Y']

    file = File.read(mappings_file)
    data_hash = JSON.parse(file)
    data_hash['mappings'].each do |m|
      product_version_name = m['product_version']
      variant_name = m['variant']
      product_version = ProductVersion.find_by_name(product_version_name) or raise "Can't find product version #{product_version_name}"
      variant = Variant.find_by_name(variant_name) or raise "Can't find variant #{variant_name}"
      released_packages = ReleasedPackage.current.where(:product_version_id => product_version, :version_id => variant)
      raise "Can't find released packages for product version #{product_version_name} variant #{variant_name}" if released_packages.empty?

      pdc_release_pdc_id = m['pdc_release']
      pdc_variant_pdc_id = m['pdc_variant']
      puts "\nCreate pdc_released_packages for pdc_release #{pdc_release_pdc_id} pdc_variant #{pdc_variant_pdc_id}"
      puts "from released_packages for product_version #{product_version_name} variant #{variant_name}"
      ActiveRecord::Base.transaction do
        # TODO: Maybe need to check if the pdc_release/pdc_variant exists in PDC server
        pdc_release = PdcRelease.get(pdc_release_pdc_id)
        pdc_variant = PdcVariant.get("#{pdc_release_pdc_id}/#{pdc_variant_pdc_id}")
        if really_do_it
          update = ReleasedPackageUpdate.create!(
            :who => User.find_by_login_name!(username),
            :reason => reason,
            :user_input => {}
          )
          released_packages.each do |legacy_rp|
            pdc_rp_attrs = legacy_rp.attributes.except("id", "product_version_id", "version_id", "updated_at", "created_at", "errata_id")
            attrs = pdc_rp_attrs.merge({:pdc_release_id => pdc_release.id, :pdc_variant_id => pdc_variant.id, :released_package_update => update})
            PdcReleasedPackage.create!(attrs)
          end
        end
      end
      puts "Added pdc_released_package for pdc_release #{pdc_release_pdc_id} pdc_variant #{pdc_variant_pdc_id}"
    end
    puts "\n\nDry run only. Add REALLY=1 to command line to really do it." unless really_do_it
  end
end
