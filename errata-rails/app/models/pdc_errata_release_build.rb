require 'set'

class PdcErrataReleaseBuild < ActiveRecord::Base

  include BuildMappingCommon

  belongs_to :pdc_errata_release

  has_one :errata, :through => :pdc_errata_release
  has_many :pdc_errata_files, :through => :errata
  has_one :pdc_release, :through => :pdc_errata_release
  has_one :release_version, :class_name => :PdcRelease,
          :through => :pdc_errata_release

  has_one :package, :through => :brew_build

  # Beware possible confusion! Defining these allows us to use the
  # build_actions method from brew_helper on these records, since they
  # are somewhat similar to ErrataBrewMapping records
  # (Todo: Probably should retire this and use one of two below)
  alias_attribute :product_version, :pdc_release

  # Allow some code blocks to work with PdcErrataReleaseBuild or
  # ErrataBrewMapping records in a (hopefully) less confusing way
  # than using product_version defined above
  alias_attribute :prod_ver_or_pdc_rel, :pdc_release
  alias_attribute :pv_or_pr, :pdc_release

  before_create do
    @was_new = true
    self.added_index = self.errata.current_state_index
  end

  after_commit do
    if @was_new
      make_new_file_listing
    end
  end

  scope :without_current_files,
    joins(:pdc_errata_release).
    joins(%{
      LEFT join pdc_errata_files AS ef
      ON pdc_errata_releases.errata_id = ef.errata_id
      AND pdc_errata_release_builds.brew_build_id = ef.brew_build_id
      AND ef.current = 1
    }).
    where("ef.brew_build_id IS NULL")

  scope :without_product_listings,
    joins(:pdc_errata_release).
    joins(
      "LEFT JOIN pdc_product_listing_caches AS plc ON " +
      "pdc_errata_release_builds.brew_build_id = plc.brew_build_id " +
      "AND pdc_errata_releases.pdc_release_id = plc.pdc_release_id"
    ).
    where("plc.cache IS NULL OR plc.cache = ?", "--- !ruby/object:OpenStruct \ntable: {}\n\n")

  def cached_product_listings
    @_cached_product_listings ||= PdcProductListing.find_or_fetch(self.pdc_release, self.brew_build, :cache_only => true)
  end

  def rpm_build_has_valid_listing?
    PdcProductListing.listings_present?(cached_product_listings)
  end

  def build_product_listing_iterator
    mappings = cached_product_listings
    return mappings if mappings.nil?

    #
    # Example listing cache structure
    #
    # --- !ruby/object:OpenStruct
    # table:
    #   :SomeVariant: !ruby/object:OpenStruct
    #     table:
    #       :x86_64: !ruby/object:OpenStruct
    #         table:
    #           :somepackage:
    #           - src
    #           - x86_64
    #           :libfoobar:
    #           - x86_64
    #
    mappings.each_pair do |variant, arches|
      arches.each_pair do |arch, rpm_arches|
        rpms = rpm_arches.to_h.keys().map(&:to_s).map(&:strip)
        brew_build.brew_files.each do |brew_file|
          name = brew_file.name_nonvr
          if rpms.include?(name) && rpm_arches[name].include?(brew_file.arch.brew_name)
            pdc_variant = PdcVariant.get_by_release_and_variant(self.pdc_release.pdc_id, variant)
            # Different to legacy iterator, here will yield more times
            # and each yield will have an arch list containing a single arch.
            yield(brew_file, pdc_variant, brew_build, [Arch.find_or_create_by_name(arch)])
          end
        end
      end
    end
  end

  def validate_rpm_versions_in_brew_build
    # Check if there is any package in the build there is older or equal than
    # the released package for the Rhn channels or Cdn repos that belong to the pdc release.
    checklist = Hash.new{|hash, key| hash[key] = []}
    checklist[:channel]  = pdc_errata_release.pdc_release.channels
    checklist[:cdn_repo] = pdc_errata_release.pdc_release.cdn_repos

    error_messages = []
    checked_combination = Set.new()
    checklist.each do |_, channels_or_cdn_repos|
      channels_or_cdn_repos.each do |channel_or_cdn_repo|
        rpms = brew_build.brew_rpms
        pdc_variant = PdcVariant.get_by_release_and_variant(self.pdc_errata_release.pdc_release.pdc_id,
                                                            channel_or_cdn_repo.variant_uid)
        arch = Arch.find_or_create_by_name(channel_or_cdn_repo.arch)
        next unless checked_combination.add?([pdc_variant, arch])

        results = PdcReleasedPackage.last_released_packages_by_variant_and_arch(pdc_variant, arch, rpms,
                                                                                {:validate_version => true})
        error_messages.concat(results[:error_messages]) if !results[:error_messages].empty?
      end
    end
    if !error_messages.empty?
      errors.add(:brew_build, "Unable to add build '#{brew_build.nvr}'.")
      errors[:brew_build].concat(error_messages)
    end
  end

  def obsolete!
    return unless self.current?
    logger.debug "Obsoleting map #{self.id}"
    self.current = 0
    self.removed_index = self.errata.current_state_index
    PdcErrataReleaseBuild.transaction do
      self.save!
      invalidate_files
      invalidate_external_test_runs
    end
  end

  def variants
    pdc_release.pdc_variants
  end

  def invalidate_external_test_runs
    external_test_runs.active.each(&:make_inactive!)
  end

  def external_test_runs
    ExternalTestRun.where(:errata_id => errata.id, :brew_build_id => brew_build.id)
  end

  def is_pdc?
    true
  end

  def rhel_release_name
    pdc_release.rhel_release
  end
end
