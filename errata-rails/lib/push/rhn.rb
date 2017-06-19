require 'fileutils'
require 'tps/tps_exceptions'

module Push
  class Rhn
    include Push::Dist

    # This file may be loaded from within rake, where rails autoloading is not functional.
    # In that case, skip this part.  (Has no effect on the parts of this used via rake)
    begin
      extend ApplicationHelper
    rescue NameError
    end

    PUSH_OPTIONS = [:bumpissue,
                    :bumpupdate,
                    :errataupload,
                    :incpushcount,
                    :modbugzilla,
                    :pkgupload,
                    :pushtorhn,
                    :rhn_pkgupload,
                    :shadow]

    attr_reader :job
    attr_accessor :push_user

    def initialize(errata,type, trace = nil, job = nil)
      raise "Bad push type: #{type}" unless [:live, :stage].include?(type)
      @errata = errata

      @type = type
      unless trace
        trace = lambda do |level, msg|
          RHNLOG.send(level, msg)
        end
      end
      @traceback = trace
      @push_user = MAIL['default_qa_user']
      @job = job


    end

    def self.make_hash_for_push(errata,
                                pushed_by,
                                do_shadow = false)

      rhn_hash = Hash.new
      ["description", "solution", "keywords", "obsoletes", "cve", "multilib", "crossref",
      "reference", "topic", "advisory_name", "revision", "issue_date", "update_date", "errata_type",
      "synopsis", "security_impact"].each do |k|
        m = {"errata_type" => "short_errata_type"}.fetch(k, k)
        rhn_hash[k] = errata.send(m.to_sym)
      end

      rhn_hash['packages'] = errata.packages.map(&:name)
      ['description', 'solution', 'topic'].each do |f|
        rhn_hash[f] = rhn_hash[f].errata_word_wrap
      end
      rhn_hash['reboot_suggested'] = errata.reboot_suggested?
      if errata.reboot_suggested?
        # NOTE: keywords is now a string and is converted to an array later.
        rhn_hash['keywords'] += ' reboot_suggested'
      end
      rhn_hash['revision'] = errata.pushcount + 1
      rhn_hash['product'] = errata.product.name
      if errata.text_only?
         rhn_hash['rhn_channel'] = errata.text_only_channel_list.channel_list.split(',')
      else
        rhn_hash['errata_files'] = Push::Rhn.errata_files(errata, do_shadow)
      end

      rhn_hash['bugs'] = []
      errata.bugs.each do |b|
        next if b.is_private?
        ref = Hash.new
        ref['id'] = b.bug_id
        ref['status'] = b.bug_status
        ref['summary'] = b.short_desc
        rhn_hash['bugs'] << ref
      end

      add_jira_to_hash(errata, rhn_hash)

      unless rhn_hash['keywords'].empty?
        rhn_hash['keywords'] = rhn_hash['keywords'].split(/[\s,]+/).reject(&:blank?)
      end

      rhn_hash['erratum_deployed_by'] = pushed_by
      rhn_hash['issue_date'] = errata.issue_date.strftime("%Y-%m-%d")
      rhn_hash['update_date'] = errata.update_date.strftime("%Y-%m-%d")

      if errata.supports_oval?
        viewer = TextRender::OvalRenderer.new(errata)
        rhn_hash['oval'] = viewer.get_text
      end
      rhn_hash
    end

    # Gets the list of rhn channels for the advisory; can be restricted by release and arch.
    # If not restricted by release and arch, will call brew to get the updated product listing map
    # to generate the correct channel list.
    #
    # Expects:
    #   <code>advisory</code> - The name or id of the erratum
    #   <code>variant</code> - Optional release to restrict the search to
    #   <code>arch</code> - Optional arch to restrict the search to
    def self.channels_for_errata(errata, variant_filter = nil, arch_filter = nil)
      uniq_channels = Set.new
      rpm_channel_map(errata) do |brew_build, rpm, variant, arch, channels, mapped_channels|
        next unless variant_filter.nil? || variant_filter == variant.rhel_variant
        next unless arch_filter.nil? || arch_filter == arch
        uniq_channels.merge(channels.try(:to_a))
        uniq_channels.merge(mapped_channels.to_a)
      end
      uniq_channels.delete(nil)
      uniq_channels.to_a
    end

    def self.troubleshoot_tps(errata)
      self.dist_troubleshoot_tps(:rhn, errata)
    end

    def self.get_channels_for_tps(errata)
      return [] unless errata.supports_rhn_stage? || errata.supports_rhn_live?

      uniq_channels = Set.new
      uniq_mapped_channels = Set.new
      Push::Rhn.rpm_channel_map(errata) do |_, _, _, _, channels, mapped_channels|
        uniq_channels.merge(channels.try(:to_a))
        uniq_mapped_channels.merge(mapped_channels.try(:to_a))
      end

      uniq_channels.delete(nil)
      uniq_mapped_channels.delete(nil)

      if errata.is_pdc?
        uniq_channels = uniq_channels.collect {|c| Channel.find_by_name(c.name)}
        uniq_mapped_channels = uniq_mapped_channels.collect {|c| Channel.find_by_name(c.name)}
      end
      # Select only channels which have the 'use for TPS scheduling?' flag set
      uniq_channels = uniq_channels.select(&:can_be_used_for_tps?)
      uniq_mapped_channels = uniq_mapped_channels.select(&:can_be_used_for_tps?)

      # If a RHEL Advisory contains package in:
      # - both parent channels and sub channels, then the parent channel will be used for TPS job.
      # - only 1 sub channel, then the sub channel will be used for TPS job.
      # - multiple sub channels with the same parent, then they will be grouped into 1 TPS job and
      #   their parent channel will be used.
      tps_channels = if errata.product.is_rhel?
        Tps::DistReposGrouping.new(uniq_channels).group_by_parent.to_a
      else
        uniq_channels
      end

      TPSLOG.debug{"initial channels for #{errata.id}: #{tps_channels.map(&:name).sort.join(',')}"}
      TPSLOG.debug{"initial mapped channels for #{errata.id}: #{uniq_mapped_channels.map(&:name).sort.join(',')}"}

      # Append with the multiple product channels.
      tps_channels.concat(uniq_mapped_channels).uniq!

      # No system running 'Main' stream can ever be subscribed to the mismatched channels:
      tps_channels.reject! &:invalid_on_main_stream?

      TPSLOG.debug{"final channels for #{errata.id}: #{tps_channels.map(&:name).sort.join(',')}"}

      tps_channels
    end

    def self.errata_files(errata, do_shadow = false)
      if do_shadow
        unless errata.release.allow_shadow?
          raise "Release #{errata.release.name} for errata #{errata.advisory_name} does not support shadow channels"
        end
      end

      files = ftp_files(errata, {:shadow => do_shadow})
      uniq_ftp = Hash.new {  |hash, key| hash[key] = []}
      files.each {|f| uniq_ftp[f['ftppath']] << f}


      errata_files = []
      uniq_ftp.each_pair do |path, hashes|
        if hashes.length > 1
          merged = { }
          merged['ftppath'] = path
          merged['md5sum'] = hashes.first['md5sum']
          merged['rhn_channel'] = []
          hashes.each do |h|
            merged['rhn_channel'].concat(h['rhn_channel'])
          end
          errata_files << merged
        else
          errata_files << hashes.first
        end
      end
      return errata_files.sort_by{|f| f['ftppath']}
    end

    def self.ftp_files(errata, opts = {})
      ftp_files = Hash.new
      rpm_channel_map(errata, opts) do |brew_build, rpm, variant, arch, channels, mapped_channels|
        path = Ftp.make_ftp_path(rpm,variant,arch)
        ref = ftp_files[path] ||= {
          'md5sum' => rpm.md5sum,
          'ftppath' => path,
          'rhn_channel' => Set.new
        }
        channel_names = (channels + mapped_channels).collect {|c| c.name}
        channel_names.collect! {|c| c += '-shadow'} if opts[:shadow]
        channel_names.collect! {|c| c += '-debuginfo'} if rpm.is_debuginfo?
        ref['rhn_channel'].merge channel_names
      end
      files = ftp_files.values
      files.each {|f| f['rhn_channel'] = f['rhn_channel'].to_a.sort}
      return files
    end

    # Yields the brew build, rpm, variant, arch and set of channels for each build
    # mapped to the advisory.
    #
    # ==== options
    # * <tt>:shadow</tt> - Check against mutually exclusive fast track, eus usage. -shadow added to base names at higher level.
    # * <tt>:ignore_debuginfo_exclusion</tt> - Ignores exclusion rules for debuginfo. Used when just want all possible mapping, mostly by tps.
    # * <tt>:ignore_srpm_exclusion</tt> - Ignores exclusion rules for srpms. Used when just want all possible mapping, mostly by tps.
    #
    def self.rpm_channel_map(errata, opts = {}, &block)
      # cache ftp exclusion calculations
      no_src_ftp = {}
      is_ftp_excluded = lambda do |map|
        args = [map.package, map.product_version]
        unless no_src_ftp.include?(args)
          no_src_ftp[args] = FtpExclusion.is_excluded?(*args)
        end
        no_src_ftp[args]
      end

      rpm_select = lambda do |map,rpm,variant,arch_list|
        # Assume all the rpms in pdc_release will be selected
        if errata.is_pdc?
          true
        else
          skip = rpm.is_debuginfo? && map.product_version.forbid_rhn_debuginfo? && !opts[:ignore_debuginfo_exclusion]
          skip ||= rpm.is_srpm? && is_ftp_excluded.call(map) && !opts[:ignore_srpm_exclusion]
          !skip
        end
      end

      self.file_channel_map(errata, {
          :mappings => errata.build_mappings.for_rpms,
          :file_select => rpm_select
        }.merge(opts),
        &block)
    end

    def self.file_channel_map(errata, opts = {}, &block)
      return {} if errata.has_docker?
      opts = opts.dup

      unless errata.is_pdc?
        # Apply package restrictions here as well as any given file_select.
        # Currently there are no package restrictions for PDC advisories.
        opts[:file_select] = Predicates.and(
          lambda{|map,file,variant,arch_list| map.package.supports_rhn?(variant)},
          opts[:file_select])
      end

      opts[:get_dists] = lambda do |map, file, variant, arch|
        if errata.is_pdc?
          # debuginfo and shadow channels are added into the list further
          # up the stack based on the rpm types and other options
          variant.channels.reject {|c| c.name =~ /debuginfo|shadow/}
        else
          classes = errata.channel_types(map.product_version, opts)
          map.product_version
            .active_channels
            .where('channel_links.variant_id = ? and arch_id = ? and type in (?)',
            variant,
            arch,
            classes)
        end
      end

      Push::Dist.file_dist_map(errata, opts, &block)
    end

    def self.get_packages_by_errata(errata, restrict_channel = nil)
      channel_files = Hash.new { |hash, key| hash[key] = SortedSet.new}
      # check if the errata is rhn support
      if errata.supports_rhn_stage? || errata.supports_rhn_live?
        rpm_channel_map(errata, {:ignore_srpm_exclusion => true}) do |brew_build, rpm, variant, arch, channels, mapped_channels|
          (channels+mapped_channels).each do |channel|
            next if restrict_channel && restrict_channel != channel
            channel_files[channel.name] << rpm.file_path
          end
        end
      end
      channel_files
    end

    def self.get_released_packages_by_errata(errata, restrict_channel = nil)
      self.get_dist_released_packages_by_errata(:rhn, errata, restrict_channel) do |product_version, channel,released_package|
        (exclude_debuginfo_rpm?(released_package.brew_rpm, product_version)) ? nil : released_package.full_path
      end
    end

    private

    def self.add_jira_to_hash(errata, rhn_hash)
      issues = errata.jira_issues.only_public.sort_by(&:key)

      if Settings.jira_as_references
        # we must not provide more text in this field than we could under normal circumstances.
        maxlen = Content.columns_hash['reference'].limit

        issues.each do |ji|
          newref = [rhn_hash['reference'], ji.url].reject(&:blank?).join("\n")
          if newref.length > maxlen
            Rails.logger.warn "Dropped some JIRA issue references for #{errata.fulladvisory}; exceeded max limit on reference field!"
            return
          end

          rhn_hash['reference'] = newref
        end
      else
        rhn_hash['jira_issues'] = issues.map do |ji|
          {
            'key' => ji.key,
            'status' => ji.status,
            'summary' => ji.summary
          }
        end
      end
    end

    def self.exclude_debuginfo_rpm?(rpm, product_version)
      rpm.is_debuginfo? && product_version.forbid_rhn_debuginfo?
    end

    def info(msg)
      @traceback.call(:info, msg)
    end

    def error(msg)
      @traceback.call(:error, msg)
    end
  end
end
