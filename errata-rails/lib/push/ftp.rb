module Push
  module Ftp
    FTP_ROOT = '/ftp/pub/redhat/linux/updates/enterprise/'
    # Returns a mapping of ftp paths to files in the errata.
    def self.ftp_dev_file_map(errata)
      raise "Cannot create an ftp map for unsigned advisory #{errata.fulladvisory}" unless errata.is_signed?
      paths = Hash.new

      errata.build_mappings.for_rpms.each do |map|
        map.build_product_listing_iterator do |rpm,variant, brew_build, arch_list|
          next unless rpm.is_debuginfo? || rpm.is_srpm?
          next if rpm.is_srpm? && FtpExclusion.is_excluded?(map.package, map.product_version)
          next if rpm.is_debuginfo? && exclude_debuginfo?(map)
          arch_list.each {|a| paths[self.make_ftp_path(rpm, variant, a)] = rpm.file_path}
        end
      end
      return paths
    end

    def self.brew_ftp_map(errata)
      ftp_map = Hash.new { |hash, key| hash[key] = { }}

      errata.build_mappings.for_rpms.each do |map|
        nvr = map.brew_build.nvr
        if ftp_map[nvr].empty?
          ftp_map[nvr][:sig_key] = map.brew_build.sig_key.keyid
          ftp_map[nvr][:rpms] = HashList.new
        end

        map.build_product_listing_iterator do |rpm,variant, brew_build, arch_list|
          next unless rpm.is_debuginfo? || rpm.is_srpm?
          next if rpm.is_debuginfo? && exclude_debuginfo?(map)

          next if rpm.is_srpm? && FtpExclusion.is_excluded?(map.package, map.product_version)
          arch_list.each do |a|
            ftp_map[nvr][:rpms][rpm.rpm_name] << self.get_ftp_dir(rpm, variant, a)
          end
          ftp_map[nvr][:rpms][rpm.rpm_name].uniq!
        end
        ftp_map.delete(nvr) if ftp_map[nvr][:rpms].empty?
      end

      return ftp_map
    end

    def self.exclude_debuginfo?(build_mapping)
      # For now we'll assume all PDC advisories exclude debuginfo. See BZ#1450363
      return true if build_mapping.is_pdc?

      build_mapping.product_version.rhel_release.exclude_ftp_debuginfo?
    end

    def self.get_ftp_dir(rpm,variant,arch)
      # For legacy advisories the variant will be a Variant record.
      # For PDC advisories it will be something else, (currently a
      # symbol), so this is a good enough way to set is_pdc
      is_pdc = !variant.is_a?(Variant)
      return self.pdc_get_ftp_dir(rpm, variant, arch) if is_pdc

      path = FTP_ROOT
      product_uses_enterprise_directories = variant.product_version.is_at_least_rhel5?

      if product_uses_enterprise_directories
        path = '/ftp/pub/redhat/linux/enterprise/'
        rhel_version = variant.rhel_variant.name
        if rhel_version =~ /([0-9].+?)-/
          rhel_version = $1
        end
      elsif variant.product_version.is_zstream?
        rhel_version = variant.name
        if variant.product.short_name == 'LACD' && rhel_version =~ /(4AS|4ES)/
          rhel_version = $1
        end
      else
        rhel_version = variant.rhel_variant.name
      end

      product = variant.product
      if rhel_version == '3Desktop' && product.short_name != 'LACD'
        rhel_version = '3desktop'
      end

      if product.short_name == 'LACD'
        rhel_version += '-LACD'
      end
      path += [rhel_version, 'en', variant.product.ftp_subdir].join('/')
      path += '/'

      arch_name = arch.name
      if rhel_version.index('3') == 0 && arch_name == 'x86_64'
        arch_name = 'AMD64'
      end

      if rpm.is_srpm?
        path += 'SRPMS'
      elsif rpm.is_debuginfo?
        if product_uses_enterprise_directories
          path += [arch_name,'Debuginfo'].join('/')
        else
          path += ['Debuginfo', arch_name, 'RPMS'].join('/')
        end
      else
        path += arch_name
      end
      path += '/'

      return path
    end

    #
    # Example ftp path:
    #  /ftp/pub/redhat/linux/enterprise/7Workstation/en/os/x86_64/anaconda-dracut-19.31.123-1.el7.x86_64.rpm
    #
    def self.pdc_get_ftp_dir(rpm, variant, arch)
      # For non-SRPMS the path does not matter
      return "/ftp/pub/path/ignored/" unless rpm.is_srpm?

      unless ftp_path_repo = variant.ftp_path_repos(content_category: 'source').first
        # TODO: This will cause a surprise error when pushing, so we should consider trying to detect it earlier
        raise "No ftp.redhat.com source repository found in PDC for #{variant.pdc_id}!"
      end

      # Add trailing slash
      File.join(ftp_path_repo.name, '')
    end

    # Given a variant, arch and rpm, generate the correct ftp path
    def self.make_ftp_path(rpm,variant,arch)
      return get_ftp_dir(rpm,variant,arch) + rpm.rpm_name
    end

    #
    # Given an errata object, check if there are any missing files.
    # Returns an array of the missing file names (or an empty array).
    #
    def self.errata_files_missing(errata)
      #
      # Short circuited to always succeed in non-prod environments.
      # (Though maybe staging should run it for real though since qestage
      # has a /mnt/redhat which is usually where it looks for files ??).
      #
      return [] unless Rails.env.production?

      # Find what files are supposed to be there
      files_required = self.ftp_dev_file_map(errata).values

      # Return the ones that are missing (if any)
      self.missing_local_files(files_required)
    end

    #
    # Given an array of file names, return an array of the
    # files that don't exist in the local file system.
    # (Returns an empty array if all files are present).
    #
    def self.missing_local_files(file_names)
      file_names.uniq.reject { |file_name| File.exist?(file_name) }
    end
  end
end
