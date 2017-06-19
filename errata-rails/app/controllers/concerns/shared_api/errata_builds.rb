module SharedApi::ErrataBuilds
  include SharedApi::Params

  # this is expected to be overridden in controllers including this module
  # if more appropriate behavior can be implemented, e.g. using flash[:notice]
  # for UI-related controllers.
  def show_notice(messages)
    write_log(:info, messages)
  end

  def show_alert(messages)
    write_log(:warn, messages)
  end

  def write_log(type, messages)
    if self.respond_to?(:log_message, true)
      log_message(type, messages)
    else
      raise NotImplementedError, "log_message method is not defined in the controller."
    end
  end

  def self.handle_argument_errors(method)
    define_method("#{method}_with_argument_error_handling".to_sym) do |*args,&block|
      begin
        self.send("#{method}_without_argument_error_handling".to_sym, *args, &block)
      rescue ArgumentError => e
        return show_error "Incorrect parameters: #{e.message}"
      end
    end
    alias_method_chain method, :argument_error_handling
  end

  # If you have file types A, B, C and then you decide to reselect just A, B,
  # the process is:
  #   * obsolete mappings for C
  #   * keep original mapping for A, B
  def update_builds_from_errata(errata, build_params)
    to_remove = []
    to_create = []

    build_params.each do |build_id, build_args|
      build = build_from_param(build_id) # build_id or build_nvr

      next unless errata.brew_builds.include?(build)

      pv_to_reselect = build_args[:product_versions]
      next if pv_to_reselect.blank?

      pv_to_reselect.each do |pv_id, pv_args|
        pv = product_version_from_param(pv_id)

        # get candidate removable mappings from the errata
        # NOTE: don't use errata.errata_brew_mappings as that
        # excludes duplicates, which need to be removed as well
        ErrataBrewMapping.where(
          :errata_id => errata,
          :current => 1,
          :brew_build_id => build,
          :product_version_id => pv).each do |m|
          to_remove << m
        end

        # get all reselect types
        file_types = pv_args[:file_types]
        archive_types = file_types.map{|t| archive_type_from_param(t)}
        archive_types.uniq.each do |type|
          # refresh candidate new create mapping from the reselect
          to_create << [build, pv, type]
        end
      end
    end

    # validate the mappings we're about to create
    to_create.each do |build,pv,archive_type|
      # clean present mappings
      if (m = errata.errata_brew_mappings.find_by_brew_build_id_and_product_version_id_and_brew_archive_type_id(build.id, pv.id, archive_type)).present?
        to_remove.delete(m)
        to_create.delete([build, pv, archive_type])
      end
    end

    # Everything is good, let's do it!
    ActiveRecord::Base.transaction do
      # Remove obsolete mappings part
      to_remove.each(&:obsolete!)
      # Creat new mappings part
      # All builds is based on present valid builds. It have no chance
      # to get a mapping invalid when user save a reselect build.
      maps = to_create.map do |build,pv,archive_type|
        ErrataBrewMapping.new(
          :product_version => pv,
          :errata => errata,
          :brew_build => build,
          :package => build.package,
          :brew_archive_type => archive_type)
      end

      maps.each(&:save!)

      errata.reload
      errata.update_content_types

      schedule_rpmdiff_runs(errata)
    end

    return errata
  end
  handle_argument_errors :update_builds_from_errata

  def add_builds_to_errata(errata, build_params)
    to_create = []

    handle_build = lambda do |nvr, build_args|
      build = begin
        BrewBuild.make_from_rpc_without_mandatory_srpm(nvr)
      rescue StandardError => e
        return show_error "Brew error for build #{nvr}: #{e.message}"
      end

      # Arg for product_versions can be an ET product version or a PDC release
      build_args[:product_versions].each do |p_id, p_args|
        if errata.is_pdc?
          pv_or_pr = pdc_release_from_param(p_id)
          unless (all_pr=errata.available_pdc_releases).include?(pv_or_pr)
            raise ArgumentError, "Pdc release #{p_id} can't be used with this advisory; available: #{all_pr.map(&:short_name).sort.join(',')}"
          end
        else
          pv_or_pr = product_version_from_param(p_id)
          unless (all_pv=errata.available_product_versions).include?(pv_or_pr)
            raise ArgumentError, "Product version #{p_id} can't be used with this advisory; available: #{all_pv.map(&:short_name).sort.join(',')}"
          end
        end

        # FIXME: Does it make sense to set a default rpm type
        file_types = p_args[:file_types] || ['rpm']
        archive_types = file_types.map{|t| archive_type_from_param(t)}
        archive_types.uniq.each{|type| to_create << [build, pv_or_pr, type]}
      end
    end

    build_params.each do |nvr, build_args|
      handle_build.call(nvr, build_args)
    end

    builds_to_create = to_create.map(&:first)
    # Docker builds and RPMs can't go in the same advisory
    if (errata.has_rpms?   || builds_to_create.any?(&:has_rpm?)) &&
       (errata.has_docker? || builds_to_create.any?(&:has_docker?))
      return show_error 'Docker image builds and RPM builds cannot be added to the same advisory'
    end

    brew = Brew.get_connection

    # validate the mappings we're about to create
    to_create.each do |build, pv_or_pr, archive_type|
      if errata.is_pdc?
        if errata.pdc_errata_releases && errata.pdc_errata_releases.find_by_pdc_release_id(pv_or_pr.id)
          pdc_errata_release_id = errata.pdc_errata_releases.find_by_pdc_release_id(pv_or_pr.id).id
          if errata.pdc_errata_release_builds.find_by_brew_build_id_and_pdc_errata_release_id(build.id, pdc_errata_release_id).present?
            raise ArgumentError, "Build #{build.nvr} already added to errata id #{errata.id} (for pdc release #{pv_or_pr.short_name}). Changing the archive type to a build already added is not supported via the API. Please remove the build and add it again."
          end
        end
      else
        if errata.errata_brew_mappings.find_by_brew_build_id_and_product_version_id(build.id, pv_or_pr.id).present?
          raise ArgumentError, "Build #{build.nvr} already added to errata id #{errata.id} (for product version #{pv_or_pr.short_name}). Changing the archive type to a build already added is not supported via the API. Please remove the build and add it again."
        end
      end

      #
      # Why is this not a validation method in ErrataBrewMapping?
      # Problematic testing: The fixture data (test_helper:179) is setup
      # without valid tags. During setup, brew tries to compare data
      # which it retrieves via list_tags through XMLRPC.
      # Stubbing/Mocking this out is way too much work for fixing
      # #1028222.
      #
      if !brew.build_is_properly_tagged?(errata, pv_or_pr, build)
        return show_error brew.errors_to_a
      end

      # For html, we already fetch and validate the product listing in the preview
      # page. Thus, it should be ok to skip the product listing fetch here.
      unless request.format.html?
        if archive_type.nil? && error = build.listing_error(pv_or_pr)
          return show_error "#{build.nvr}: #{error}"
        end
      end
    end

    # Everything is good, let's do it!
    ActiveRecord::Base.transaction do
      all_package_p = Set.new
      maps = to_create.map do |build, pv_or_pr, archive_type|
        all_package_p.add [build.package, pv_or_pr]
        if errata.is_pdc?
          pdc_errata_release = errata.pdc_errata_releases.find_by_pdc_release_id(pv_or_pr.id)
          pdc_errata_release ||= PdcErrataRelease.new(:errata => errata, :pdc_release => pv_or_pr)
          PdcErrataReleaseBuild.new(
            :brew_build => build,
            :pdc_errata_release => pdc_errata_release,
            :brew_archive_type => archive_type)
        else
          ErrataBrewMapping.new(
            :product_version => pv_or_pr,
            :errata => errata,
            :brew_build => build,
            :package => build.package,
            :brew_archive_type => archive_type)
        end
      end

      if (badmaps = maps.reject(&:valid?)).any?
        return show_error badmaps.map{|m| m.errors.messages.values.flatten.join(' ')}.join("\n")
      end

      # note that this will also obsolete mappings for file types other than what
      # the user requested.  This is intentional as it's assumed that we shouldn't
      # be mixing older/newer versions of files of different types.
      all_package_p .each{|package, pv_or_pr| brew.discard_old_package(errata, pv_or_pr, package)}

      # Since it had already validated before, I will turn the validation off here
      maps.each{|m| m.save(:validate => false)}

      # Enable supports_multiple_product_destinations if any mapping is found
      # and currently unset.
      if errata.supports_multiple_product_destinations.nil?
        should_enable_multi_product = all_package_p.any? do |package, pv_or_pr|
          # Currently we don't support multi-product mappings for PDC advisories. This may change in fuuture
          !pv_or_pr.is_pdc? && MultiProductMap.mappings_for_product_version_package(pv_or_pr, package).any?
        end
        errata.update_attributes!(:supports_multiple_product_destinations => true) if should_enable_multi_product
      end

      errata.reload
      errata.update_content_types

      schedule_rpmdiff_runs(errata)
    end

    errata
  end
  handle_argument_errors :add_builds_to_errata

  def schedule_rpmdiff_runs(errata)
    if (error_messages = RpmdiffRun.schedule_runs(errata, current_user.login_name)).any?
      show_alert(error_messages)
    end
  end

  # Remove build from errata, we don't care the user selected file types.
  # We will also remove all mappings from the brew build.
  def remove_builds_from_errata(errata, build_params)
    to_remove = []

    build_params.each do |build_id,build_args|
      build = build_from_param(build_id) # build_id or build_nvr

      next unless errata.brew_builds.include?(build)

      pv_or_pr_to_remove = build_args[:product_versions]
      # when invoke from API,eg referring to api/v1/erratum_controller, the product_version will be blank.
      if pv_or_pr_to_remove.blank?
        if errata.is_pdc?
          pdc_errata_release_id = errata.pdc_errata_release_builds.where(:brew_build_id => build).pluck('DISTINCT pdc_errata_release_id')
          pv_or_pr_to_remove = errata.pdc_errata_releases.where(:id => pdc_errata_release_id).pluck('DISTINCT pdc_release_id').map{|pr_id| [pr_id, {}]}
        else
          pv_or_pr_to_remove = errata.errata_brew_mappings.where(:brew_build_id => build).pluck('DISTINCT product_version_id').map{|pv_id| [pv_id, {}]}
        end
      end

      pv_or_pr_to_remove.each do |pv_or_pr_id, pv_args|
        file_types = (begin; pv_args[:file_types]; rescue; end) || []
        archive_types = file_types.map{|t| archive_type_from_param(t)}

        if errata.is_pdc?
          pv_or_pr = pdc_release_from_param(pv_or_pr_id)
          pdc_errata_release = errata.pdc_errata_releases.where(:pdc_release_id => pv_or_pr)
          errata.pdc_errata_release_builds.where(:brew_build_id => build, :pdc_errata_release_id => pdc_errata_release).each do |m|
            if archive_types.empty? || archive_types.include?(m.brew_archive_type)
              to_remove << m
            end
          end
        else
          pv_or_pr = product_version_from_param(pv_or_pr_id)
          errata.errata_brew_mappings.where(:brew_build_id => build, :product_version_id => pv_or_pr).each do |m|
            if archive_types.empty? || archive_types.include?(m.brew_archive_type)
              to_remove << m
            end
          end
        end
      end
    end

    if to_remove.empty?
      show_notice('There are no builds to remove.')
      return errata
    end

    ActiveRecord::Base.transaction do
      to_remove.each(&:obsolete!)
      errata.update_content_types
    end

    removed_nvr = to_remove.map{|m| m.brew_build.nvr}.sort.uniq
    show_notice("Removed #{removed_nvr.join(', ')} from advisory.")
    return errata
  end
  handle_argument_errors :remove_builds_from_errata
end
