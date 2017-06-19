namespace :debug do
  namespace :released_packages do

    desc "Show manual overrides that were older than existing release packages"
    task :show_overrides => :environment do

      #
      # Add some useful scopes to ReleasedPackage
      #
      ReleasedPackage.class_eval do
        scope :non_current,
          where(:current => false)

        scope :added_manually,
          where('errata_id IS NULL')

        scope :for_package,
          lambda { |package| where(:package_id => package) }

        scope :for_build,
          lambda { |brew_build| where(:brew_build_id => brew_build) }

        scope :for_variant,
          lambda { |variant| where(:version_id => variant) }

        scope :for_arch,
          lambda { |arch| where(:arch_id => arch) }

        scope :for_errata,
          lambda { |errata| where(:errata_id => errata) }

        scope :for_product_version,
          lambda { |product_version| where(:product_version_id => product_version) }

        scope :for_product_version_by_name,
          lambda { |product_version_name| for_product_version(ProductVersion.find_by_name(product_version_name)) }

        scope :created_between,
          lambda { |from_time, to_time| where('released_packages.created_at > ? AND released_packages.created_at < ?', Time.parse(from_time.to_s), Time.parse(to_time.to_s)) }

        scope :for_variant_arch,
          lambda { |variant, arch| for_variant(variant).for_arch(arch) }

        scope :for_rhel6,
          for_product_version_by_name('RHEL-6')
      end

      #
      # So we can sort brew builds properly by nvr
      #
      BrewBuild.class_eval do
        include RpmVersionCompare

        def name_nonvr
          self.package.name
        end
      end

      #
      # Find a record in released packages table that is non current, but was
      # added automatically by Errata Tool when an advisory was shipped.
      #
      def find_newest_non_current_released_package(package, variant, arch)
        ReleasedPackage.
          non_current.
          for_rhel6.
          for_package(package).
          for_variant_arch(variant, arch).
          sort{|a,b| a.brew_build.compare_versions(b.brew_build)}.
          last
      end

      #
      # Have to look it up since we do a select distinct above
      #
      def find_manually_added_date(brew_build, variant, arch)
        ReleasedPackage.
          current.
          for_build(brew_build).
          for_variant_arch(variant, arch).
          order('created_at').
          limit(1).
          first.
          created_at
      end

      #
      # Want to examine these particular released package records.
      # (Adjust as required).
      #
      check_released_packages = ReleasedPackage.
        current.
        for_rhel6.
        added_manually.
        joins(:package).
        #
        # Uncomment this to test just the original examples
        #where('packages.name = "samba" OR packages.name = "ipa"').
        #
        # It finds a handful of newer ones with this commented out, but not many
        #created_between("2015-03-23 00:00:00 UTC", "2015-03-24 00:00:00 UTC").
        #
        select('distinct brew_build_id, version_id, arch_id, package_id').
        order('LOWER(packages.name)')

      # Sanity check two examples from the original ticket:
      examples = Errata.where(:id => [20073, 20024]).map(&:errata_brew_mappings).map(&:first)
      examples.each { |m| puts ">>Before: #{ReleasedPackage.get_previously_released_nvr(m)}" }

      #
      # For each of them compare with the non-current automatically added nvr
      #
      check_released_packages.each do |current_rp|
        puts "\nLooking at #{current_rp.variant.product_version.name} #{current_rp.variant.name} #{current_rp.brew_build.try(:nvr)} #{current_rp.arch.name}..."
        non_current_rp = find_newest_non_current_released_package(current_rp.package, current_rp.variant, current_rp.arch)
        next unless non_current_rp

        # See if it's newer
        current_build = current_rp.brew_build
        non_current_build = non_current_rp.brew_build
        puts "** Found manually added record from #{non_current_rp.created_at}. Leaving as is." if current_build == non_current_build
        next unless non_current_build.is_newer?(current_build)

        # Print out some details
        errata = non_current_rp.errata
        added_date = find_manually_added_date(current_build, current_rp.variant, current_rp.arch)

        puts "#{current_build.nvr} for #{current_rp.arch.name} #{current_rp.variant.name} added on #{added_date} " +
          "is older than #{non_current_build.nvr} " +
          if errata
            "shipped in #{errata.fulladvisory} on #{errata.actual_ship_date}!"
          else
            "added manually on #{non_current_rp.created_at}"
          end

        records_to_disable = ReleasedPackage.current.for_build(current_build).for_variant_arch(current_rp.variant, current_rp.arch)
        records_to_enable_with_dupes_maybe = ReleasedPackage.non_current.for_build(non_current_build).for_variant_arch(non_current_rp.variant, non_current_rp.arch)

        # Because we can get manual and non-manual items with the same brew rpm, have to pick just one per brew_rpm
        records_to_enable = records_to_enable_with_dupes_maybe.group_by{ |r| [r.brew_rpm.id, r.brew_rpm.arch_id] }.values.map do |records|
          # Prefer one with an errata id, then prefer the oldest one..
          records.sort_by{ |r| [r.errata_id || 99999999, r.created_at] }.first
        end


        #
        # Show what we would do
        #
        display_record = lambda { |r| "#{r.id} #{r.brew_build_id} #{r.brew_rpm.name} #{r.brew_rpm.arch.name} e:#{r.errata_id||'nil'} #{r.created_at}" }

        puts " Disabling #{records_to_disable.count} records. #{records_to_disable.map(&:id).inspect}"
        puts "  - " + records_to_disable.map(&display_record).join("\n  - ")

        puts " Enabling #{records_to_enable.count} records. #{records_to_enable.map(&:id).inspect}"
        puts "  + " + records_to_enable.map(&display_record).join("\n  + ")

        puts "** Note: Enabling some manually added released package records" if records_to_enable.any?{ |r| r.errata_id.nil? }

        #
        # Do it (maybe)
        #
        if ENV['FIX_IT'] == '1'
          ActiveRecord::Base.transaction do
            records_to_disable.update_all(:current => false)
            records_to_enable.each{ |r| r.update_attribute(:current,true) }
            puts " Fixed!"
          end
        end

      end

      # See https://bugzilla.redhat.com/show_bug.cgi?id=1211477#c2
      examples.each { |m| puts ">>After: #{ReleasedPackage.get_previously_released_nvr(m)}" }

    end

  end
end
