module Push
  class Cdn
    include Push::Dist

    # @param errata [Errata]
    # @return Array(Array<CdnRepo>,Array<CdnRepo>)
    def self.cdn_repos_for_errata(errata)
      uniq_repos = Set.new
      uniq_mapped_repos = Set.new
      rpm_repo_map(errata) do |brew_build, rpm, variant, arch, repos, mapped_repos|
        uniq_repos.merge(repos.try(:to_a))
        uniq_mapped_repos.merge(mapped_repos)
      end

      uniq_repos = uniq_repos.to_a.compact
      uniq_mapped_repos = uniq_mapped_repos.to_a.compact
      if errata.is_pdc?
        uniq_repos = uniq_repos.map {|c| CdnRepo.find_by_name(c.name)}.compact
        uniq_mapped_repos = uniq_mapped_repos.map {|c| CdnRepo.find_by_name(c.name)}.compact
      end
      [uniq_repos, uniq_mapped_repos]
    end

    def self.troubleshoot_tps(errata)
      self.dist_troubleshoot_tps(:cdn, errata) do |uniq_repos, dist_handler|
        unless Settings.enable_tps_cdn
          raise Tps::PushTypeDisabledError.new(dist_handler.type)
        end
        uniq_repos.flatten.select(&:is_binary_repo?)
      end
    end

    # @param errata [Errata]
    # @return Array<CdnRepo>
    def self.get_repos_for_tps(errata)
      unless Settings.enable_tps_cdn
        Rails.logger.warn "Settings.enable_tps_cdn turned off. Will not return CDN repos for TPS scheduling."
        return []
      end
      return [] unless errata.supports_cdn?

      (uniq_repos, mapped_repos) = cdn_repos_for_errata(errata)
      # Select only cdn repos which have the 'use for TPS scheduling?' flag set
      uniq_repos = uniq_repos.select(&:can_be_used_for_tps?)
      mapped_repos = mapped_repos.select(&:can_be_used_for_tps?)

      # If a RHEL Advisory contains package in:
      # - both parent cdn repos and sub cdn repos, then the parent cdn repo will be used for TPS job.
      # - only 1 sub cdn repo, then the sub cdn repo will be used for TPS job.
      # - multiple sub cdn repos with the same parent, then they will be grouped into 1 TPS job and
      #   their parent cdn repo will be used.
      tps_cdn_repos = if errata.product.is_rhel?
        Tps::DistReposGrouping.new(uniq_repos).group_by_parent.to_a
      else
        uniq_repos
      end

      tps_cdn_repos.concat(mapped_repos).uniq!

      # No system running 'Main' stream can ever be subscribed the mismatched repos
      tps_cdn_repos.reject! &:invalid_on_main_stream?

      if tps_cdn_repos.empty?
        Rails.logger.warn "No CDN repositories found for advisory #{errata.id}. TPS scheduling will not work."
      end

      tps_cdn_repos
    end

    # (See also type_matches_rpm?)
    def self.repo_class_for_brew_file(brew_file)
      return CdnSourceRepo if brew_file.respond_to?(:is_srpm?) && brew_file.is_srpm?
      return CdnDebuginfoRepo if brew_file.respond_to?(:is_debuginfo?) && brew_file.is_debuginfo?
      return CdnDockerRepo if brew_file.is_docker?
      return CdnBinaryRepo
    end

    def self.file_repo_map(errata, opts = {}, &block)
      opts = opts.dup

      unless errata.is_pdc?
        # Apply package restrictions here as well as any given file_select.
        # Currently there are no package restrictions for PDC advisories.
        opts[:file_select] = Predicates.and(
          lambda{|map,file,variant,arch_list| map.package.supports_cdn?(variant)},
          opts[:file_select])
      end

      opts[:get_dists] = lambda do |map, file, variant, arch|
        repos = if errata.is_pdc?
                  content_category = repo_class_for_brew_file(file).pdc_content_category
                  variant.cdn_repos(content_category: content_category)
                else
                  release_types = errata.cdn_repo_types(map.product_version, opts)
                  map.product_version
                     .active_repos
                     .where(
                       'type = ? and cdn_repo_links.variant_id = ? and arch_id = ? and release_type in (?)',
                       repo_class_for_brew_file(file).to_s,
                       variant,
                       arch,
                       release_types)
                end

        if file.is_docker?
          # Only return repos that are mapped to package
          repos &= file.package.cdn_repos
        end

        repos
      end

      Push::Dist.file_dist_map(errata, opts, &block)
    end

    def self.rpm_repo_map(errata, opts = {}, &block)
      self.file_repo_map(errata, opts.merge(:mappings => errata.build_mappings.for_rpms), &block)
    end

    def self.get_packages_by_errata(errata, restrict_repo = nil)
      repo_files = Hash.new { |hash, key| hash[key] = SortedSet.new }
      if errata.supports_cdn?
        rpm_repo_map(errata) do |brew_build, rpm, variant, arch, repos, mapped_repos|
          [repos,mapped_repos].flatten.each do |repo|
            next if restrict_repo && restrict_repo != repo
            repo_files[repo.name] << rpm.file_path
          end
        end
      end
      repo_files
    end

    def self.get_released_packages_by_errata(errata, restrict_repo = nil)
      self.get_dist_released_packages_by_errata(:cdn, errata, restrict_repo) do |product_version, cdn_repo, released_package|
        # srpm goes to CdnSourceRepo, debuginfo goes to CdnDebuginfoRepo, rpm goes to CdnBinaryRepo
        (cdn_repo.type_matches_rpm?(released_package.brew_rpm)) ? released_package.full_path : nil
      end
    end
  end
end
