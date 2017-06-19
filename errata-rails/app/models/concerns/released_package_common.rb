module ReleasedPackageCommon
  extend ActiveSupport::Concern

  included do
    attr_writer :check_brew_build_version

    belongs_to :package
    belongs_to :arch
    belongs_to :brew_rpm
    belongs_to :brew_build
    belongs_to :errata
    has_one :released_package_audit
    has_one :released_package_update, :through => :released_package_audit

    scope :current, where(:current => true)

    validate :brew_build_version, :if => "check_brew_build_version?"
  end

  module ClassMethods

    def released_packages_from_attrs!(attrs, opts = {})
      check_version = opts.fetch(:check_brew_build_version, false)
      release_version_id = "#{release_version}_id"

      out = []
      attrs.uniq.group_by{|x| x.slice(release_version, :package)}.each do |key,these_attrs|
        flag_as_outdated = self.current.
          where(release_version_id => key[release_version], :package_id => key[:package]).
          map(&:id)

        self.transaction do
          these_attrs.each do |x|
            out << self.create!(x.merge(:check_brew_build_version => check_version))
          end
          self.where(:id => flag_as_outdated).update_all(:current => false)
        end
      end
      out
    end

    def attrs_from_mappings(errata)
      out = []
      errata.build_mappings.for_rpms.each do |map|
        out.concat(attrs_from_mapping(map))
      end
      out
    end

    def attrs_from_rhn(errata)
      out = []
      Push::Rhn.rpm_channel_map(errata, &attrs_from_push_map(errata, out))
      out
    end

    def attrs_from_cdn(errata)
      out = []
      Push::Cdn.rpm_repo_map(errata, &attrs_from_push_map(errata, out))
      out
    end

    # Returns true if str starts with any terminal node of trie.
    def trie_has_prefix?(trie, str)
      node = trie.root
      str.chars.each do |c|
        if node.walk!(c)
          if node.terminal?
            return true
          end
        else
          return false
        end
      end
      false
    end

    # Finds released packages of the same subpackage as the given RPMs,
    # returned in a structure like this:
    #
    #  {'some-subpackage'  => [rp1, rp2, ...],
    #   'other-subpackage' => [rp3, rp4, ...],
    #   ...}
    #
    # Each value in the hash is an array of released packages, where each released
    # package will be the same NVR (and the newest currently in the database), but
    # will be different arches.
    def for_brew_rpms(brew_rpms)
      all_nonvr_names = brew_rpms.map(&:name_nonvr).uniq
      like_clause = like_clause_for_rpm_names(all_nonvr_names)

      return {} if like_clause.blank?

      all_nonvr_names = all_nonvr_names.to_set

      # Use includes instead of joins here to prevent doing more sql queries.
      scoped.
        includes(:brew_rpm).
        where(like_clause).
        each_with_object(HashList.new) do |rp, h|
        current_rpm = rp.brew_rpm
        current_name = current_rpm.name_nonvr
        next unless all_nonvr_names.include?(current_name)

        got = h[current_name]
        cmp = got.empty? ? 0 : current_rpm.compare_versions(got[0].brew_rpm)
        if cmp == 0
          # Same version, or first time we've seen this subpackage.
          got << rp
        elsif cmp > 0
          # Newer version.  Overwrite anything we currently have.
          got.clear
          got << rp
        else
          # old version.  Ignore.
        end
      end
    end

    # Given a list of RPM names, excluding the version and release portion,
    # returns an SQL fragment matching released packages starting with those
    # name(s) via LIKE.
    def like_clause_for_rpm_names(all_nonvr_names)
      like_names = []
      like_names_trie = Trie.new

      all_nonvr_names.sort_by(&:length).each do |name|
        # If this name is "python-pluggy"
        # and like_names already contains "python-"
        # then it's pointless to include this name
        unless self.trie_has_prefix?(like_names_trie, name)
          name_with_dash = name + '-'
          like_names << name_with_dash
          like_names_trie.add(name_with_dash)
        end
      end

      like_names.map{ |n| "brew_files.name like '#{n}%'" }.join(' OR ')
    end

    # Cache to prevent repeated lookups
    def kernel_id
      @_kernel_id ||= Package.find_by_name('kernel').id
    end
    def kernel_aarch64_id
      @_kernel_aarch64_id ||= Package.find_by_name('kernel-aarch64').id
    end

    def _get_last_released_packages(released_packages, brew_rpms, the_variants, opts)
      results = {:list => Set.new, :error_messages => []}
      # the list is empty means no packages had been released for the rpms
      return results if released_packages.empty?

      brew_rpms.each do |brew_rpm|
        next if opts[:exclude_debuginfo] && brew_rpm.is_debuginfo?
        rpm_name = brew_rpm.name_nonvr
        rpm_is_kernel = (brew_rpm.package_id == kernel_id)

        last_released_packages = released_packages[rpm_name]
        last_released_packages.each do |last_released_package|
          # Workaround so we can ship kernel builds with older rpms than those shipped in kernel-aarch64 builds
          skip_version_validation = (rpm_is_kernel && last_released_package.package_id == kernel_aarch64_id)

          # Make sure the new rpm version is not older than/equal to the latest released rpm in the same channel or cdn repo
          if opts[:validate_version] && !skip_version_validation && brew_rpm.compare_versions(last_released_package.brew_rpm) != 1
            # BUGBUG: Can't determine whether a package was released through cdn push or rhn push. The only way I can think of
            # is check the product version of the package and see whether it has rhn/cdn push or not. But this way will not always work,
            # because the push target of a product version can be changed by user any time.
            results[:error_messages] << "Build '#{last_released_package.brew_build.nvr}' has newer or equal version of '#{brew_rpm.rpm_name}' in '#{the_variants.map(&:name).join(', ')}' variant."
          else
            results[:list] << last_released_package
          end
        end
      end
      return results
    end
  end

  def check_brew_build_version?
    !!@check_brew_build_version
  end

end
