module Push
  @DistStruct ||= Struct.new(:type, :repo_type, :release_type, :active_repos_method)
  class DistHandler < @DistStruct
    def initialize(type)
      self.type = type
      if self.type == :rhn
        self.repo_type = :channel
        self.release_type = :type
        self.active_repos_method = :active_channels
      else
        self.repo_type = :cdn_repo
        self.release_type = :release_type
        self.active_repos_method = :active_repos
      end
    end

    def repo_link
      "#{self.repo_type.to_s.camelize}Link".constantize
    end

    def get_repo_by_link(link)
      link.send(self.repo_type)
    end

    def get_repos_links(repos)
      self.repo_link.includes(:variant, self.repo_type => [:arch, {:variant => [:rhel_variant]}]).\
        where(:"#{self.repo_type}_id" => repos)
    end

    def get_base_repos(rhel_variant, arch, content_type = nil)
      base_repos = rhel_variant.send(self.repo_type.to_s.pluralize).\
        where(self.release_type => "Primary#{self.repo_type.to_s.camelize}", :arch_id => arch)
      base_repos = base_repos.where(:type => content_type) if self.type == :cdn && content_type.present?
      base_repos
    end

    def active_repos(product_version)
      product_version.send(self.active_repos_method)
    end

    def self.get_repo_type(repos)
      Array.wrap(repos).first.kind_of?(Channel) ? :channel : :cdn_repo
    end

    def self.get_dist_type(repos)
      Array.wrap(repos).first.kind_of?(Channel) ? :rhn : :cdn
    end

    def supports_dist?(errata)
      (errata.send("supports_#{self.type}_stage?") || errata.send("supports_#{self.type}_live?"))
    end
  end

  module Dist
    def self.included(base)
      base.extend(ClassMethods)
    end

    # Important options:
    #
    #  :shadow => shadow push mode, affects which types of
    #  channels/repos are yielded
    #
    #  :mappings => if set, only process these ErrataBrewMapping;
    #  otherwise, process all on the advisory.
    #
    #  :file_select => optional proc called with |map,file,variant,arch_list|
    #  which should return true only for files which should be processed.
    #
    #  :get_dists => proc called with |map, file, variant, arch|
    #  which must return all applicable dists (RHN channels or CDN repos),
    #  not including multi-product mapped dists.
    #
    #  :supports_multi_product_destinations => optional boolean that overrides
    #  the 'errata.supports_multiple_product_destinations' setting.
    #
    #  :on_multi_product_mapped => optional callback, invoked for each
    #  activated multi-product mapping rule.
    def self.file_dist_map(errata, opts = {})
      raise "Fast track and shadow are mutually exclusive!" if opts[:shadow] && opts[:fast_track]

      mappings = opts.fetch(:mappings, errata.build_mappings)
      file_select = opts.fetch(:file_select, Predicates.true)
      on_multi_product_mapped = opts.fetch(:on_multi_product_mapped, lambda{ |*args| })

      mappings.each do |map|
        map.build_product_listing_iterator do |file, variant, brew_build, arch_list|
          next unless file_select.call(map, file, variant, arch_list)

          arch_list.each do |arch|
            dists = opts[:get_dists].call(map, file, variant, arch)
            next if dists.empty?

            mapped_dists = if errata.is_pdc?
                             # Currently we don't support multi-product mappings for PDC advisories
                             []
                           else
                             multi_product_mappings = self.get_mappings(errata, map.package, dists, opts.slice(:supports_multi_product_destinations))

                             # We need to filter the given mappings by product
                             # listings.  We need to use product listings of the
                             # destination product version, and only keep the mapping
                             # if this file is included in those listings.
                             filtered_mappings = multi_product_mappings.select{|m|
                               self.should_use_multi_product_mapping?(m, file, arch)}

                             filtered_mappings.each(&on_multi_product_mapped)
                             filtered_mappings.map(&:destination).uniq
                           end
            yield(brew_build, file, variant, arch, dists, mapped_dists)
          end
        end
      end
    end

    # Return true if a MultiProduct*Map should be used for the given
    # file and arch.  (Consults product listings.)
    def self.should_use_multi_product_mapping?(mapping, file, arch)
      ProductListing.build_product_listing_iterator(
        :product_version => mapping.destination_product_version,
        :brew_build => file.brew_build,
        :file_select => lambda{|inner_file| file == inner_file}) \
      do |_,_,_,inner_arch_list|
        # The mapping is valid if the product listing for that
        # product version includes this file for this arch.
        #
        # NOTE: currently we are not doing the file_select again (from
        # file_dist_map) in this inner loop.
        #
        # This means, for example, we could select a mapping
        # for a file even if that file's package is not
        # normally allowed to push to RHN/CDN for the mapped
        # variant.
        #
        # I'm not sure if that's a feature or a bug.  Possibly
        # a feature as it allows configuring a product version
        # so that a package can _only_ be shipped to that
        # product version via a multi-product advisory from
        # another product, which seems a reasonable thing to
        # do.
        if inner_arch_list.include?(arch)
          return true
        end
      end
      false
    end

    def self.get_mappings(errata, package, dist_repos, opts = {})
      supports_multi_product_dests = opts.fetch(:supports_multi_product_destinations, errata.supports_multiple_product_destinations)
      return [] unless supports_multi_product_dests

      type  = DistHandler.get_repo_type(dist_repos).to_s
      klass = "MultiProduct#{type.camelize}Map".constantize
      klass.mappings_for_package(dist_repos, package)
    end

    # Helper method to figure out the RPMs to be used during released package
    # lookup.
    #
    # +dist_to_variants+ is a hash where each key is a dist (repo or channel)
    # and each value is an array of variants. These are used to filter the
    # returned RPMs.
    #
    # Returns an array of hashes, each with elements :dist, :rpm, :variants,
    # :arch, to be used in the query for released packages.
    def self.get_rpms_for_released_packages(errata, mappings, dist_to_variants)
      # Normally, in the file_dist_map, we're using the currently active
      # repos/channels where content will really be pushed.
      #
      # When querying for released packages, there's some other logic which
      # takes "variant inheritance" into account and builds up a list of repos
      # mapped to variants.  We're passed that list, and reuse it in here.
      #
      # First, we arrange it into a structure for efficient lookup from within
      # get_dists.
      variant_and_arch_to_dists = HashList.new
      dist_to_variants.each do |dist, variants|
        variants.each do |variant|
          variant_and_arch_to_dists[[variant.id, dist.arch_id]] << dist
        end
      end

      is_rhel = errata.product.is_rhel?
      get_dists = lambda do |_, _, variant, arch|
        (
          variant_and_arch_to_dists[[variant.id, arch.id]] +
          # For RHEL advisory, also return the base dist to check whether the old rpms existed in the base dist.
          # RHEL advisory normally groups base + sub dists into a single TPS job. However, layered product
          # advisory runs each sub dist TPS job separately.
          (is_rhel ? variant_and_arch_to_dists[[variant.rhel_variant_id, arch.id]] : [])
        ).uniq
      end

      # Caller wants this structure:
      # {[variants, arch] => {:rpms => <...>, :dists => <...>}]
      out = Hash.new do |h,k|
        h[k] = {:rpms => Set.new, :dists => Set.new}
      end

      Push::Dist.file_dist_map(errata, :mappings => Array.wrap(mappings),
                               :get_dists => get_dists) do |_, rpm, _, arch, dists, mapped_dists|
        (dists + mapped_dists).each do |dist|
          key = [dist_to_variants[dist], arch]
          inner = out[key]
          inner[:rpms] << rpm
          inner[:dists] << dist
        end
      end
      out
    end

    module ClassMethods

      def dist_troubleshoot_tps(dist_type, errata, &block)
        tps_error = nil
        dist_handler = DistHandler.new(dist_type.to_sym)
        # call channels_for_errata or cdn_repos_for_errata
        uniq_repos = self.send("#{dist_handler.repo_type.to_s.pluralize}_for_errata", errata)

        begin
          uniq_repos = block.call(uniq_repos, dist_handler) if block

          if !dist_handler.supports_dist?(errata)
            # push type not supported
            raise Tps::PushTypeNotSupportedError.new(dist_handler.type)
          elsif uniq_repos.empty?
            # no repo is applicable to the advisory
            raise Tps::NoApplicableRepositoryError.new(dist_handler.type)
          elsif (disabled_repos = uniq_repos.reject(&:can_be_used_for_tps?)).any?
            # some repos are being set to disabled tps scheduling
            if errata.is_pdc?
              message = disabled_repos.map(&:name).join(', ')
              raise Tps::TpsSchedulingDisabledError.new(dist_handler.type, [], message)
            else
              raise Tps::TpsSchedulingDisabledError.new(dist_handler.type, disabled_repos)
            end

          else
            # otherwise, still raise a standard tps error with custom message
            custom_message = lambda {|repo_type| "All #{repo_type.pluralize} have TPS scheduling enabled" }
            raise Tps::TpsStandardError.new(dist_handler.type, custom_message)
          end
        rescue Tps::TpsStandardError => error
          tps_error = error
        end

        return tps_error
      end

      # Get previously released versions of packages for a given advisory, in
      # the format expected by TPS.
      #
      # +dist_type+     - :rhn or :cdn
      # +restrict_dist+ - if provided, the result only includes data for this
      #                   channel/repo (hence will have only 0 or 1 top-level
      #                   keys).
      #
      # Accepts a mandatory block, which receives: |product_version, dist, released_package|
      # The block should return the value of released_package.full_path if the package
      # should be included in the output, nil otherwise.
      #
      # Returns a hash like this:
      #
      #   {"some_dist_name" => ["/mnt/redhat/brewroot/path/to/pkg1.rpm",
      #                         "/mnt/redhat/brewroot/path/to/pkg2.rpm",
      #                         ...],
      #    "other_dist_name" => ["/mnt/redhat/brewroot/path/to/pkg1.rpm",
      #                          "/mnt/redhat/brewroot/path/to/otherpkg.rpm",
      #                         ...],
      #    ...}
      #
      def get_dist_released_packages_by_errata(dist_type, errata, restrict_dist = nil)
        dist_to_files = Hash.new { |hash, key| hash[key] = SortedSet.new }
        dist_handler = DistHandler.new(dist_type.to_sym)

        return dist_to_files unless dist_handler.supports_dist?(errata)

        # If we are not RHEL (i.e. we are a layered product), variant/repo lookup changes a bit.
        is_rhel  = errata.product.is_rhel?
        mappings = errata.errata_brew_mappings.for_rpms.includes(:product_version, :package, :brew_build => [:brew_rpms])

        # Need these for the cache
        brew_build_ids = []
        product_version_ids = []
        mappings.each do |m|
          brew_build_ids << m.brew_build_id
          product_version_ids << m.product_version_id
        end
        brew_build_ids.uniq!
        product_version_ids.uniq!

        ThreadLocal.with_thread_locals(
                                       # Most of this data is accessed from the nested calls to file_dist_map.
                                       # Preloading and caching here helps avoid repeatedly loading the same data.
                                       :cached_arches => Arch.prepare_cached_arches,
                                       :cached_files => BrewBuild.prepare_cached_files(brew_build_ids),
                                       :cached_restrictions => Package.prepare_cached_package_restrictions(mappings.map(&:package_id)),
                                       :cached_listings => ProductListingCache.prepare_cached_listings(product_version_ids, brew_build_ids)
                                       ) do
          mappings.group_by(&:product_version).each_pair do |product_version, et_maps|
            # Find the dists and variants for this product version...
            pv_active_dists = dist_handler.active_repos(product_version)
            pv_dist_to_variants = get_inherited_variants(pv_active_dists, is_rhel)

            et_maps.group_by(&:package).each do |package, package_maps|
              # ... add the dists and variants from multi-product mappings.
              # These are processed here since they're configurable per-package.
              mapped_dists = Push::Dist.get_mappings(errata, package, pv_active_dists).map(&:destination) if pv_active_dists.any?
              mapped_dists ||= []
              full_dist_to_variants = get_inherited_variants(mapped_dists, true)
              full_dist_to_variants.merge!(pv_dist_to_variants)

              # Filter out some values from the full dist => variants map
              # depending on passed parameters and package push target
              # restrictions
              dist_to_variants = HashList.new
              full_dist_to_variants.each do |dist, variants|
                next if restrict_dist && dist != restrict_dist

                variants = variants.select{ |v| package.send("supports_#{dist_handler.type}?", v) }
                next if variants.empty?

                dist_to_variants[dist] = variants
              end

              # Now we need to find out which subpackages would be pushed to which dists (via which variants),
              # so we can accurately look up only the relevant subpackages.
              push_info = Push::Dist.get_rpms_for_released_packages(errata, package_maps, dist_to_variants)

              push_info.each do |(variants, dist_arch), grouped_push_info|
                rpms  = grouped_push_info[:rpms].to_a
                dists = grouped_push_info[:dists].to_a

                # This fetches the last released version of each subpackage for the given arch and any of the variants.
                # Note: the arch is the arch of the dist which may differ from the arch of RPMs, e.g. an x86_64
                # RHN channel may also accept noarch and i386 RPMs.
                released_packages = ReleasedPackage.last_released_packages_by_variant_and_arch(variants, dist_arch, rpms)

                released_packages[:list].each do |released_package|
                  dists.each do |dist|
                    dist_name = dist.name
                    rpm_full_path = yield(product_version, dist, released_package)
                    dist_to_files[dist_name] << rpm_full_path unless rpm_full_path.nil?
                  end
                end
              end
            end
          end
        end
        dist_to_files
      end

      # Get and group all variants that are link to a x-stream channel
      # Example output:
      # 'rhel-x86_64-server-6' =>
      #   ["6Server", "6Server-6.2.z", "6Server-6.3.z", "6Server-6.4.z", "6Server-6.5.z", "6Server-6.6.z"]
      #
      # 'rhel-x86_64-server-6' channel is expected to contain all packages that shipped to the variants above(z-stream channels)
      #
      def get_inherited_variants(dist_repos, is_rhel)
        return {} unless dist_repos.any?

        dist_handler = DistHandler.new(DistHandler.get_dist_type(dist_repos))
        found_base_repos = {}

        return dist_handler.\
          get_repos_links(dist_repos).\
          each_with_object(HashList.new) do |l,h|
            dist_repo = dist_handler.get_repo_by_link(l)
            h[dist_repo] << l.variant
            next if is_rhel

            # For layered products, tps expecting the last released packages from both base channel and child channel.
            # - Because all layered products channels are child channels.
            # - A machine can subscribe to one base channel, plus any|none of the child channels
            #
            # <jwl_home> There are base channels (which correspond to tps streams, fwiw), and a collection of child channels.
            # <jwl_home> A machine can subscribe to one base channel, plus any|none of the child channels
            # <jwl_home> usually the newest package in the [base + children] set is considered the old/released package.
            # <jwl_home> It gets complicated, though, for layered products
            # <jwl_home> I think they break the rules a bit...
            # <jwl_home> I think tomcat is a package which exists in multiple versions across layered products.  There are probably others.
            # <jwl_home> layered products are all child channels
            # <jwl_home> in that case, I'd expect a return to list the channel name, and latest version present in it
            # <jwl_home> and let the user (tps in this case) figure out what ought to apply
            # <jwl_home> tps is expecting packages from both base and child channelS; it can determine which channels are applicable
            # <jwl_home> since ET can't possibly know what the test system is actually subscribed to
            # <jwl_home> but TPS does
            # <jwl_home> This might actually need to be tested, to be sure TPS handles odd cases correctly
            # <jwl_home> for example, if the box is subscribed to channel1 & channel2 -- and channel1 has foo-1, while channel2 has foo-2.
            # <jwl_home> tps should not pick up both foo-1 and foo-2 by mistake :)
            #
            # Related RT tickets for missing base channel last released packages for layered products
            # - https://engineering.redhat.com/rt/Ticket/Display.html?id=312966
            # - https://engineering.redhat.com/rt/Ticket/Display.html?id=312784

            rhel_variant = dist_repo.variant.rhel_variant
            arch = dist_repo.arch
            key = [rhel_variant, arch]
            # For CDN repo, we need to categorize based on content type (source, debuginfo or binary) in order
            # to get the correct base CDN repo.
            # For example:
            # rhn-tools-for-rhel-6-server-rpms__x86_64           -> rhel-6-server-rpms__6Server__x86_64
            # rhn-tools-for-rhel-6-server-debuginfo-rpms__x86_64 -> rhel-6-server-debuginfo-rpms__6Server__x86_64
            # rhn-tools-for-rhel-6-server-source-rpms__x86_64    -> rhel-6-server-source-rpms__6Server__x86_64
            key << dist_repo.type if dist_handler.type == :cdn

            # if the base repos are cached, then use it.
            base_repos = if found_base_repos.has_key?(key)
              found_base_repos[key]
            else
              found_base_repos[key] = dist_handler.get_base_repos(*key)
              found_base_repos[key]
            end
            # Bug 1204280: Group the released packages that we found from the base channel/cdn repo
            # into the sub-channel/cdn repos respectively to avoid confusing TPS with mixed information that
            # might not be needed by every job.
            h[dist_repo].concat(get_inherited_variants(base_repos, true).values.flatten)
          end
      end
    end
  end
end
