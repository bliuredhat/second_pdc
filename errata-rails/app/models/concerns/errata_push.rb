module ErrataPush
  extend Memoist
  extend ActiveSupport::Concern

  included do
    alias_method :supports_cdn_live?, :supports_cdn?
  end

  # Like memoize, but:
  # - no deprecation warning
  # - clears memoized data on reload
  # - does not use memoized data if changed? is true
  def self.memoize_blockers(method_sym)
    define_method("#{method_sym}_with_memo") do |*args|
      delegate = "#{method_sym}_without_memo"
      if changed?
        send(delegate, *args)
      else
        @memo ||= Hash.new{ |h, k| h[k] = Hash.new }
        @memo[method_sym][args] ||= send(delegate, *args)
      end
    end
    alias_method_chain method_sym, :memo
  end

  # Fetch all rpm variants that are used by the advisory
  # TODO: Support PDC
  def get_variants_used_by_rpms
    return {} if is_pdc?
    brew_build_map = HashList.new
    mappings = self.build_mappings.for_rpms
    product_version_ids, brew_build_ids, package_ids = collect_id_lists(mappings)

    ThreadLocal.with_thread_locals(
     :cached_restrictions => Package.prepare_cached_package_restrictions(package_ids),
     :cached_arches => Arch.prepare_cached_arches,
     :cached_files  => BrewBuild.prepare_cached_files(brew_build_ids),
     :cached_listings => ProductListingCache.prepare_cached_listings(product_version_ids, brew_build_ids)
    ) do
      mappings.group_by(&:product_version).each_pair do |product_version,mappings|
        mappings.each do |mapping|
          package = mapping.package
          mapping.build_product_listing_iterator({:cache_only => true}) do |file, variant, brew_build, arch_list|
            # Some packages are restricted to push to certain dists.
            # Exclude the package if it is not pushing to the dists.
            next if (package.supported_push_types_by_variant(variant) & self.supported_push_types).empty?

            # If the errata is multi-product supported then we need to find the
            # mapped channels by given the product listing variant and arches.
            mapped_variants = self.supports_multiple_product_destinations? ?
              self.get_mapped_variants(product_version, package, variant, arch_list) :
              []
            brew_build_map[package].concat([variant] + mapped_variants)
          end
        end
      end
    end

    brew_build_map.values.each {|v| v.uniq!}
    brew_build_map
  end

  def get_variants_for_docker
    package_variant_map = HashList.new

    docker_file_repo_map do |mapping, docker_image, repos|
      package = docker_image.package
      variants = repos.map do |repo|
        # There can be only one variant attached to repo per product_version
        mapping.product_version.variants.attached_to_cdn_repo(repo).first
      end
      package_variant_map[package] = variants.uniq if variants.any?
    end

    package_variant_map
  end

  def get_variants_by_package
    return {} if is_pdc?
    has_docker? ? get_variants_for_docker : get_variants_used_by_rpms
  end

  #
  # Returns an array of variants for an advisory.
  #
  # This works for both RPM and Docker errata. For RPM errata, product
  # listings are used, and for Docker errata, package repo mappings are
  # used.
  #
  # TODO: This won't work for PDC advisories currently
  #
  def get_variants
    return [] if is_pdc?
    get_variants_by_package.values.flatten.uniq
  end

  def get_channels(product_version, variant, arches)
    # I pass the product version as an argument because I want to retain the
    # cached product_version.channel_links
    # It is quicker to compare id than name because we don't have to do another query
    # e.g. channel.arch.name
    arch_ids = arches.map(&:id)
    types = channel_types(product_version)
    links = product_version.channel_links
    list = links.select do |l|
      c = l.channel
      types.include?(c.type) && l.variant_id == variant.id && arch_ids.include?(c.arch_id)
    end
    list.map(&:channel).uniq
  end

  def channel_types(product_version, opts = {})
    classes = []
    if self.release.is_fasttrack?
      classes << 'FastTrackChannel'
    else
      can_use_eus = !opts[:shadow] && release.is_async?
      classes << 'PrimaryChannel'
    end

    if can_use_eus && product_version.is_zstream?
      classes.concat(['EusChannel', 'LongLifeChannel'])
    end
    classes
  end

  def cdn_repo_types(product_version, opts = {})
    shared_release_types = []
    can_use_eus = false

    if self.release.is_fasttrack?
      shared_release_types << 'FastTrackCdnRepo'
    else
      can_use_eus = !opts[:shadow] && release.is_async?
      shared_release_types << 'PrimaryCdnRepo'
    end

    if can_use_eus && product_version.is_zstream?
      shared_release_types.concat(['LongLifeCdnRepo', 'EusCdnRepo'])
    end
    shared_release_types
  end

  def has_distqa_jobs?
    rhnqa?
  end

  def push_target_for_push_type(type)
    push_targets.select {|pt| pt.push_type == type}.first
  end

  def push_targets
    targets = release_versions_used_by_advisory.collect{ |rv| rv.push_targets }.flatten.uniq

    if has_docker?
      # Docker advisories should only get pushed to cdn/cdn_docker
      return targets.select{|x| ['cdn', 'cdn_docker', 'cdn_docker_stage', 'cdn_stage'].include?(x.name)}
    end
    targets
  end

  def supported_push_types
    push_targets.collect {|t| t.push_type.to_sym}.uniq
  end
  memoize :supported_push_types

  def supports_cdn?
    supported_push_types.include? :cdn
  end

  def supports_cdn_docker?
    supported_push_types.include? :cdn_docker
  end

  def supports_cdn_docker_stage?
    supported_push_types.include? :cdn_docker_stage
  end

  def supports_cdn_stage?
    supported_push_types.include? :cdn_stage
  end

  def supports_rhn_live?
    supported_push_types.include? :rhn_live
  end

  def supports_rhn_stage?
    supported_push_types.include? :rhn_stage
  end

  def supports_altsrc?
    supported_push_types.include? :altsrc
  end

  def can_push_cdn?(*args)
    push_cdn_blockers(*args).empty?
  end

  def can_push_cdn_docker?(*args)
    push_cdn_docker_blockers(*args).empty?
  end

  def can_push_cdn_docker_stage?(*args)
    push_cdn_docker_stage_blockers(*args).empty?
  end

  def can_push_cdn_stage?(*args)
    push_cdn_stage_blockers(*args).empty?
  end

  def has_pushed_cdn_live?
    has_pushed_since_last_respin?(CdnPushJob)
  end

  def has_pushed_cdn_docker?
    has_pushed_since_last_respin?(CdnDockerPushJob)
  end

  def has_pushed_cdn_docker_stage?
    has_pushed_since_last_respin?(CdnDockerStagePushJob)
  end

  def has_pushed_cdn_stage?
    has_pushed_since_last_respin?(CdnStagePushJob)
  end

  # True if the most recent RHN stage push succeeded and was more recent than
  # the last time this advisory was NEW_FILES.
  def has_pushed_rhn_stage?
    return true if rhnqa? || rhnqa_shadow?

    has_pushed_since_last_respin?(RhnStagePushJob)
  end

  def has_pushed_rhn_live?
    has_pushed_since_last_respin?(RhnLivePushJob)
  end

  def has_pushed_altsrc?
    has_pushed_since_last_respin?(AltsrcPushJob)
  end

  #
  # Hacky way to deal with the situation on the new push UI where
  # the user might push to both LIVE and to CDN with one click,
  # so the SHIPPED_LIVE test can't be used exclude CDN pushes.
  #
  def can_push_cdn_if_live_push_succeeds?(*args)
    push_cdn_if_live_push_succeeds_blockers(*args).empty?
  end

  def can_push_rhn_live?(*args)
    push_rhn_live_blockers(*args).empty?
  end

  def can_push_rhn_stage?(*args)
    push_rhn_stage_blockers(*args).empty?
  end

  def can_push_ftp?(*args)
    push_ftp_blockers(*args).empty?
  end

  def can_push_altsrc?(*args)
    push_altsrc_blockers(*args).empty?
  end

  def has_active_cdn_repos?
    release_versions_used_by_advisory.any?{|rv| rv.active_cdn_repos.any?}
  end

  def has_any_packages_for_push_type?(push_type)
    build_mappings.any? do |m|
      out = false
      if self.is_pdc?
        out ||= m.pdc_release.push_targets.pluck(:push_type).include?(push_type.to_s)
      else
        m.build_product_listing_iterator(:cache_only => true) do |brew_file, variant, brew_build, arches|
          out ||= brew_build.package.supported_push_types_by_variant(variant).include?(push_type)
        end
      end
      out
    end
  end

  def common_skip_reasons(push_type)
    type_name = push_type.to_s.titleize
    if !self.send("supports_#{push_type}?")
      return ["Does not support #{type_name}"]
    elsif !text_only? && !has_any_packages_for_push_type?(push_type)
      # The advisory must have at least one package & variant with
      # this push type enabled, (or the advisory can be text-only)
      return ["#{type_name} is not supported by the packages in this advisory"]
    end
    []
  end

  def skip_cdn_reasons(push_type=:cdn)
    if has_docker? && push_type != :cdn_docker &&
      (docker_reasons = skip_cdn_docker_reasons).any?
      return docker_reasons
    end
    common_cdn_skip_reasons(push_type)
  end

  def skip_cdn_stage_reasons(push_type = :cdn_stage)
    if has_docker? && push_type != :cdn_docker_stage &&
      (docker_reasons = skip_cdn_docker_stage_reasons).any?
      return docker_reasons
    end
    common_cdn_skip_reasons(push_type)
  end

  def common_cdn_skip_reasons(push_type)
    unless (out = common_skip_reasons(push_type)).empty?
      return out
    end
    return ["There are no CDN Repos defined for products in '#{self.fulladvisory}'"] if !has_active_cdn_repos?
    []
  end

  def skip_cdn_docker_reasons(push_type = :cdn_docker)
    reasons = common_docker_skip_reasons
    return reasons if reasons.any?
    skip_cdn_reasons(push_type)
  end

  def skip_cdn_docker_stage_reasons
    reasons = common_docker_skip_reasons
    return reasons if reasons.any?
    skip_cdn_stage_reasons(:cdn_docker_stage)
  end

  def common_docker_skip_reasons
    if has_docker?
      unmapped = unmapped_docker_message
      return [unmapped] if unmapped
    else
      return ["This advisory does not contain docker images"]
    end
    []
  end

  def skip_rhn_live_reasons
    common_skip_reasons(:rhn_live)
  end

  def skip_rhn_stage_reasons
    common_skip_reasons(:rhn_stage)
  end

  [
    :cdn,
    :cdn_docker,
    :cdn_docker_stage,
    :cdn_stage,
    :rhn_live,
    :rhn_stage,
  ].each do |push_type|
    define_method("has_#{push_type}?") do
      self.send("skip_#{push_type}_reasons").empty?
    end
  end

  def has_ftp?
    product.allow_ftp? && (
      # Has one or more srpm file that will be published via ftp
      build_mappings.for_rpms.any? { |build_mapping| !FtpExclusion.is_excluded?(build_mapping.package, build_mapping.release_version) } ||
      # Or, has one or more debuginfo file that will be published via ftp
      build_mappings.for_rpms.any? { |build_mapping| build_mapping.has_debuginfo_rpm? && !Push::Ftp.exclude_debuginfo?(build_mapping) }
    )
  end

  def has_altsrc?
    self.brew_builds.any?
  end

  def push_rhn_live_blockers(options = {})
    unless (skip = skip_rhn_live_reasons).empty?
      return skip
    end
    live_push_blockers options
  end
  memoize_blockers :push_rhn_live_blockers

  def push_cdn_stage_blockers(options = {})
    if has_docker?
      if !supports_cdn_docker_stage?
        return ["Advisory contains docker images but CDN docker stage push target is not enabled."]
      end
      docker_blockers = push_cdn_docker_stage_blockers(options)
      return docker_blockers if docker_blockers.any?
    end

    common_stage_blockers(:cdn_stage, options)
  end
  memoize_blockers :push_cdn_stage_blockers

  def push_cdn_docker_stage_blockers(options = {})
    unless (skip = skip_cdn_docker_stage_reasons).empty?
      return skip
    end
    docker_blockers = common_docker_blockers
    return docker_blockers if docker_blockers.any?
    common_stage_blockers(:cdn_docker_stage, options)
  end
  memoize_blockers :push_cdn_docker_stage_blockers

  def push_rhn_stage_blockers(options = {})
    common_stage_blockers(:rhn_stage, options)
  end
  memoize_blockers :push_rhn_stage_blockers

  def push_cdn_blockers(options = {})
    _push_cdn_blockers options
  end
  memoize_blockers :push_cdn_blockers

  def _push_cdn_blockers(opts={})
    if has_docker?
      if !supports_cdn_docker?
        return ["Advisory contains docker images but CDN docker push target is not enabled."]
      end
      docker_blockers = push_cdn_docker_blockers(opts)
      return docker_blockers if docker_blockers.any?
    end

    unless (skip = skip_cdn_reasons).empty?
      return skip
    end

    # if :push_with_rhn is set, checks are adjusted slightly: it's
    # assumed that a single request will be made to push RHN and CDN
    # together.
    if opts[:push_with_rhn]
      if has_rhn_live? && !can_push_rhn_live?(opts)
        return ['This errata cannot be pushed to RHN Live, thus may not be pushed to CDN']
      end
    elsif !opts['nochannel']
      # There is no requirement to push RHN before CDN for nochannel pushes
      unless !has_rhn_live? || (status == State::SHIPPED_LIVE && published?)
        return ["Advisory has not been shipped to rhn live channels yet."]
      end
    end

    return live_push_blockers(opts)
  end

  def push_cdn_if_live_push_succeeds_blockers(options = {})
    options ||= {}
    _push_cdn_blockers options.merge(:push_with_rhn => true)
  end
  memoize_blockers :push_cdn_if_live_push_succeeds_blockers

  def push_cdn_docker_blockers(options = {})
    unless (skip = skip_cdn_docker_reasons).empty?
      return skip
    end

    docker_blockers = common_docker_blockers

    if has_active_container_errata?
      # Disabled temporarily as a workaround for METAXOR-541
      #docker_blockers << 'A docker image included in this advisory contains RPM-based advisories that have not yet been shipped'
    end

    return docker_blockers if docker_blockers.any?
    live_push_blockers(options)
  end
  memoize_blockers :push_cdn_docker_blockers

  def push_altsrc_blockers(options = {})
    unless supports_altsrc?
      return ["Altsrc pushes are not supported for this advisory"]
    end
    unless has_altsrc?
      return ['There are no packages available to push to git']
    end

    transitive_blockers('git')
  end
  memoize_blockers :push_altsrc_blockers

  # use this for ancillary push types which should be blocked whenever
  # RHN/CDN are blocked.
  def transitive_blockers(for_type)
    blocked_by = lambda{|type| ["This errata cannot be pushed to #{type}, thus may not be pushed to #{for_type}"]}

    if has_rhn_live?
      if !can_push_rhn_live?
        return blocked_by.call('RHN Live')
      elsif has_cdn? && !can_push_cdn_if_live_push_succeeds?
        return blocked_by.call('CDN Live')
      end
    elsif has_cdn? && !can_push_cdn?
      return blocked_by.call('CDN Live')
    end

    []
  end

  def push_ftp_blockers(options = {})
    blockers = []
    unless product.allow_ftp?
      return ["Cannot push #{product.name} to FTP"]
    end
    unless has_ftp?
      return ['There are no packages available to push to ftp']
    end

    blockers.concat transitive_blockers('FTP')
    blockers << 'This errata is still embargoed' if is_embargoed?
    blockers << 'This errata is not signed' unless is_signed?
    blockers
  end
  memoize_blockers :push_ftp_blockers

  def push_blockers_for(target, *args)
    send("push_#{target}_blockers", *args)
  end

  def push_ready_blockers
    # create a new index with admin role to exclude user permission
    # blockers
    i = StateIndex.new(:errata => self,
                       :who =>  Role.find_by_name('admin').users.limit(1).first,
                       :previous => self.status.to_s,
                       :current => State::PUSH_READY)
    return [] if i.valid?
    i.errors.values.flatten
  end

  def live_push_blockers(options = {})
    options ||= {}

    valid_push_states = State::LIVE_PUSH_STATES
    nochannel = options['nochannel']

    if nochannel
      # A nochannel push does not actually expose files/metadata to customers.
      # It is effectively a preload which is done prior to the usual live
      # states for improved performance.
      # Therefore it's valid to do it in the stage states as well.
      valid_push_states = valid_push_states + State::STAGE_PUSH_STATES
    end

    unless valid_push_states.include?(self.status)
      return ["State #{self.status} invalid. Must be one of: " +
        valid_push_states.join(', ')]
    end

    # Rest of live push blockers do not apply in nochannel case
    return prepush_blockers if nochannel

    # Special case.  This is not a transition guard because it is switched on/off
    # based on a system-wide setting, and it is very important that this can't
    # be bypassed for any workflow rule sets.
    if jira_blockers = jira_push_blockers
      return jira_blockers
    end

    i = StateIndex.new(:errata => self,
                       :who =>  Role.find_by_name('admin').users.limit(1).first,
                       :previous => State::PUSH_READY,
                       :current => State::IN_PUSH)
    i.validate_transition_guards
    i.errors.values.flatten
  end

  def jira_push_blockers
    if Settings.jira_private_only
      issues = self.jira_issues.only_public
      if issues.any?
        ["Can't ship with public JIRA issues. Issues must be removed or made private: #{issues.map(&:key).join(', ')}"]
      end
    end
  end

  def prepush_blockers
    out = []

    if embargo_date
      # The full day of the embargo date must have passed,
      # e.g. if embargo date is: Nov 09 11:30:00
      # then server date must be Nov 10.
      #
      # embargo_date ought to be only a date with no time, but the database
      # schema doesn't enforce this.  This code will work whether or not it has
      # a time.
      server_date = Time.now.beginning_of_day
      unless server_date > embargo_date
        out << "embargo date of #{embargo_date} must have passed"
      end
    end

    embargoed_bug_ids = embargoed_bugs.map(&:id)
    if embargoed_bug_ids.present?
      id_str = embargoed_bug_ids.sort.join(', ').truncate(100)
      out << "has embargoed bugs: #{id_str}"
    end

    out
  end

  def can_push_to?(target)
    send("can_push_#{target}?")
  end

  def push_job_since_last_state(type, state)
    push_jobs_since_last_state(type, state).order('updated_at desc').limit(1).first
  end

  def push_jobs_since_last_state(type, state)
    klass = if type.kind_of?(Class)
      type
    else
      PushJob.child_get("#{type.to_s.camelize}PushJob")
    end

    push_jobs = klass.for_errata(self)
    if !push_jobs.exists?
      return push_jobs
    end

    last_state = last_state_index(state)

    # Not every advisory has gone through every state.
    # For example a NEW_FILES advisory might not gone through QE state yet unless repin
    # All advisory should gone through NEW_FILES state at least once.
    return push_jobs.where('0 = 1') unless last_state

    when_state = last_state.updated_at

    return push_jobs.where('updated_at > ?', when_state)
  end

  # Returns true if a push of the specified type has completed since the last
  # respin of this advisory.
  #
  # Jobs which don't publish changes, such as nochannel jobs or tasks-only
  # jobs, are excluded from consideration.
  #
  # type may be either a push type as returned by supported_push_types or a PushJob class.
  def has_pushed_since_last_respin?(type)
    jobs = push_jobs_since_last_state(type, 'NEW_FILES').where('pub_task_id is not null')
    jobs.reject(&:is_nochannel?).any?(&:is_committed?)
  end

  def push_job_since_last_push_ready(type)
    push_job_since_last_state(type, 'PUSH_READY')
  end

  def common_stage_blockers(type, options={})
    blockers = self.send("skip_#{type}_reasons")
    unless blockers.empty?
      return blockers
    end

    currently_blocked_method = "currently_blocked_for_#{type}_by"
    currently_blocked_by_list = self.send(currently_blocked_method)
    if currently_blocked_by_list.any?
      blockers << "Must push dependencies to #{type.to_s.titleize} first: #{blocking_list_helper(currently_blocked_by_list, :no_status=>true)}"
    end

    blockers << 'Packages are not signed' unless is_signed?
    blockers.concat(tps_job_blockers)
    valid_push_states = State::STAGE_PUSH_STATES

    unless valid_push_states.include?(self.status)
      blockers << 'State invalid. Must be one of: ' +
        valid_push_states.join(', ')
    end
    if is_blocked?
      blockers << "Advisory is blocked: #{self.active_blocking_issue.blocking_role.name} - #{self.active_blocking_issue.summary}"
    end

    if text_only?
      tg = TextOnlyAdvisoryGuard.new()
      blockers << tg.failure_message unless tg.transition_ok?(self)
    end

    blockers
  end

  def common_docker_blockers
    blockers = []
    blockers << 'No metadata repositories selected' if docker_metadata_repos.empty?
    unmapped = unmapped_docker_message
    blockers << unmapped if unmapped
    blockers
  end

  def enforces_tps?
    return false unless requires_tps?
    # If TPS testing isn't blocking in the state machine rule set then it shouldn't block the push
    self.state_machine_rule_set.state_transition_guards.where(:type => 'TpsGuard').where("guard_type != 'info'").any?
  end

  def tps_job_blockers()
    blockers = []
    return blockers if !enforces_tps?

    if !tps_finished?
      blockers << 'TPS testing incomplete'
    end

    return blockers
  end

  def get_mapped_variants(product_version, package, variant, arches)
    mapped_channels = []
    origin_channel_ids = self.get_channels(product_version, variant, arches).map(&:id)
    if origin_channel_ids.any?
      channel_map = multi_product_channels_maps(product_version, package)
      mapped_channels = channel_map.reject{|origin,dest| !origin_channel_ids.include?(origin)}.values.flatten
    end
    mapped_channels.map(&:variant)
  end

  def docker_file_repo_map
    build_mappings.tar_files.each do |mapping|
      docker_repos = mapping.release_version.active_cdn_repos.where(:type => 'CdnDockerRepo')
      mapping.brew_files.select(&:is_docker?).each do |docker_image|
        filtered_repos = docker_repos & docker_image.package.cdn_repos
        yield mapping, docker_image, filtered_repos
      end
    end
  end

  def unmapped_docker_files
    unmapped = []
    docker_file_repo_map do |_, docker_image, repos|
      unmapped << docker_image if repos.empty?
    end
    unmapped
  end

  def untagged_docker_files
    untagged = HashList.new
    docker_file_repo_map do |mapping, docker_image, repos|
      next if repos.empty?
      package = docker_image.package
      repos.each do |repo|
        package_mapping = CdnRepoPackage.where(:package_id => package, :cdn_repo_id => repo).first
        untagged[docker_image] << repo if package_mapping.cdn_repo_package_tags.none?
      end
    end
    untagged
  end

  def unmapped_docker_message
    unmapped = unmapped_docker_files
    if unmapped.any?
      unmapped_names = unmapped.map{|f| f.brew_build.nvr}.sort.uniq.join(', ')
      return "The following Docker builds are not mapped to any CDN repositories: #{unmapped_names}"
    end

    untagged_messages = []
    untagged_docker_files.each do |image, repos|
      untagged_messages << "#{image.name} (#{repos.map(&:name).sort.join(', ')})"
    end
    if untagged_messages.any?
      return "The following Docker images are untagged in these repositories: #{untagged_messages.sort.join(', ')}"
    end

    nil
  end

  def docker_files
    brew_files.tar_files.select(&:is_docker?)
  end

  def stage_push_complete?
    (!supports_cdn_stage? || has_pushed_cdn_stage?) &&
    (!supports_rhn_stage? || has_pushed_rhn_stage?) &&
    (!supports_cdn_docker_stage? || !has_docker? || has_pushed_cdn_docker_stage?)
  end

  def supports_stage_push?
    supports_cdn_stage? || supports_cdn_docker_stage? || supports_rhn_stage?
  end

  private

  def collect_id_lists(mappings)
    product_version_ids = []
    brew_build_ids = []
    package_ids = []

    mappings.each do |et_map|
      product_version_ids << et_map.product_version_id
      brew_build_ids << et_map.brew_build_id
      package_ids << et_map.package_id
    end

    [product_version_ids, brew_build_ids, package_ids].map(&:uniq)
  end

  def multi_product_channels_maps(product_version, package)
    get_multi_product_channels_map = lambda do |product_version_id|
      MultiProductChannelMap.includes(:destination_channel).
        where(:origin_product_version_id => product_version_id).
        each_with_object({}) do |m,h|
          h[m.package_id] ||= {}
          (h[m.package_id][m.origin_channel_id] ||= []) << m.destination_channel
        end
    end

    @multi_p ||= Hash.new {|h,k| h[k] = get_multi_product_channels_map.call(k)}
    pv_map = @multi_p[product_version.id]
    pv_map[package.id] || {}
  end
end
