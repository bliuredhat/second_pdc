# == Schema Information
#
# Table name: errata_brew_mappings
#
#  id                 :integer       not null, primary key
#  errata_id          :integer       not null
#  brew_build_id      :integer       not null
#  build_tag          :string
#  product_version_id :integer       not null
#  package_id         :integer       not null
#  current            :integer       default(1), not null
#  created_at         :datetime      not null
#

require 'brew'

class ErrataBrewMapping < ActiveRecord::Base

  VALID_FLAGS = %w[
    buildroot-push
    ack-product-listings-mismatch
  ]

  include BuildMappingCommon

  belongs_to :product_version
  belongs_to :release_version, :class_name => :ProductVersion,
             :foreign_key => :product_version_id

  belongs_to :package

  belongs_to :errata,
  :class_name => "Errata",
  :foreign_key => 'errata_id'

  has_many :rpmdiff_runs

  scope :without_product_listings,
    joins(
      "LEFT JOIN product_listing_caches AS plc ON " +
      "errata_brew_mappings.brew_build_id = plc.brew_build_id " +
      "AND errata_brew_mappings.product_version_id = plc.product_version_id"
    ).
    where("plc.cache IS NULL OR plc.cache = ?", "--- {}\n\n")

  scope :without_current_files,
    joins(%{
      LEFT join errata_files AS ef
      ON errata_brew_mappings.errata_id = ef.errata_id
      AND errata_brew_mappings.brew_build_id = ef.brew_build_id
      AND ef.current = 1
    }).
    where("ef.brew_build_id IS NULL")

  delegate :rhel_variants, :to => :product_version

  #
  # Going to use errata_brew_mappings to find a big list of what
  # packages/product_versions "belong together". This is so we don't
  # show the user package/product version combinations are non-sensical
  # and could never happen which we would do if we were showing every
  # possible combination. (Not sure if that is the best or correct-est
  # way to do it). This is used in
  # FtpExclusionsController#lookup_package_exclusions.
  #
  scope :search_by_pkg_prod_ver_or_prod, lambda { |package_match, product_version_match, product_match|
    select('DISTINCT package_id, product_version_id'). # This works but seems confusing! We don't care about the other columns.
    joins(:package, :product_version, 'JOIN errata_products ON errata_products.id = product_versions.product_id').
    includes(:package, :product_version). # can't include product???
    where(
      # Some quick and dirty substring searching...
      '
        LCASE(packages.name) LIKE ?
        AND LCASE(product_versions.name) LIKE ?
        AND LCASE(errata_products.short_name) LIKE ?
      ',
      "%#{package_match.downcase.strip}%",
      "%#{product_version_match.downcase.strip}%",
      "%#{product_match.downcase.strip}%"
    ).
    order('errata_products.short_name, product_versions.name, packages.name')
  }

  validates_presence_of :package, :brew_build, :product_version, :errata
  validate :validate_product_version, :on => :create
  validate :validate_flags

  before_create do
    @was_new = true
    self.added_index = self.errata.current_state_index
    self.spin_version = self.errata.respin_count + 1
  end

  after_commit do
    if @was_new
      make_new_file_listing
    end
  end

  # Allow some code blocks to work with PdcErrataReleaseBuild or
  # ErrataBrewMapping records
  alias_attribute :prod_ver_or_pdc_rel, :product_version
  alias_attribute :pv_or_pr, :product_version

  def external_test_runs
    ExternalTestRun.where(:errata_id => errata.id, :brew_build_id => brew_build.id)
  end

  def reload(*args)
    @_product_listing = nil
    super
  end

  def rpm_build_has_valid_listing?
    if self.brew_archive_type_id.nil?
      @_product_listing ||= ProductListingCache.cached_listing(self.product_version, self.brew_build)
      @_product_listing && @_product_listing.any?
    else
      # non rpms always map always return true
      true
    end
  end

  def has_docker?
    brew_archive_type_id == BrewArchiveType::TAR_ID && brew_files.any?(&:is_docker?)
  end

  def build_product_listing_iterator(listing_options={}, &block)
    return docker_file_iterator(&block) if has_docker?

    ProductListing.build_product_listing_iterator(listing_options.merge(
      :product_version => product_version,
      :brew_build => brew_build,
      :file_select => lambda{|file| file.brew_archive_type_id == self.brew_archive_type_id}),
      &block)
  end

  def docker_file_iterator
    # Product listings are not used for docker, so this is used instead
    # See also: ProductListing.build_product_listing_iterator
    brew_files.select(&:is_docker?).each do |brew_file|
      package.cdn_repos.enabled.where(:type => 'CdnDockerRepo').each do |repo|
        repo.cdn_repo_links.each do |link|
          next unless link.variant.product_version == product_version
          yield(brew_file, link.variant, brew_build, [ repo.arch ])
        end
      end
    end
  end

  def update_sig_state
    return false if Rails.env.development?
    return false if brew_build.signed_rpms_written?

    brew = Brew.get_connection
    key = product_version.sig_key.keyid
    return false if brew.queryRPMSigs(brew_build.brew_rpms.first.id_brew, key).empty?

    # Assume that if the first rpm is signed, then they all are, as signing is
    # an all or nothing process
    brew_build.mark_as_signed(product_version.sig_key)
    return true
  end

  def release!
    ActiveRecord::Base.transaction do
      self.shipped = 1
      self.brew_build.released_errata = self.errata

      self.brew_build.save!
      self.save!
    end
  end

  def product_listing_files
    build_product_listing_iterator{}.values.flatten.map(&:brew_file).uniq
  end

  def rpm_files_not_in_listings
    return [] unless for_rpms?
    brew_build.brew_rpms - product_listing_files
  end

  def variants
    product_version.variants
  end

  def is_pdc?
    false
  end

  def rhel_release_name
    product_version.rhel_release.name
  end

  private

  def validate_rpm_versions_in_brew_build
    # Check if there is any package in the build there is older or equal than
    # the released package for the Rhn channels or Cdn repos that belong to the product version.
    checklist = Hash.new{|hash, key| hash[key] = []}
    checklist[:channel]  = product_version.channel_links if product_version.supports_rhn?
    checklist[:cdn_repo] = product_version.cdn_repo_links if product_version.supports_cdn?

    error_messages = []
    checklist.each do |type, links|
      links.each do |link|
        channel_or_cdn_repo = link.send("#{type}")
        rpms = brew_build.brew_rpms
        results = ReleasedPackage.last_released_packages_by_variant_and_arch(link.variant, channel_or_cdn_repo.arch, rpms, {:validate_version => true})
        error_messages.concat(results[:error_messages]) if !results[:error_messages].empty?
      end
    end
    if !error_messages.empty?
      errors.add(:brew_build, "Unable to add build '#{brew_build.nvr}'.")
      errors[:brew_build].concat(error_messages)
    end
  end

  #
  # This is to ensure, that mappings are created only for the advisories
  # available product versions and not for product versions which are
  # invalid/don't belong to the advisory.
  #
  # Don't validate if this ErrataBrewMapping is obsolete (current==0).
  #
  def validate_product_version
    unless errata.available_product_versions.include? product_version
      errors.add(:product_version, "Invalid product version given: #{product_version.name}. Expected one of #{errata.available_product_versions.map(&:name).join(', ')}")
    end
  end

  def validate_flags
    changed = new_record? || flags_changed?

    # Only check the changed flags, because historical records should
    # not suddenly become invalid if the rules change.
    return unless changed

    old_flags = flags_changed? ? flags_was : Set.new

    added_flags = flags - old_flags
    removed_flags = old_flags - flags
    invalid_flags = added_flags - VALID_FLAGS
    forbidden_flags = added_flags - invalid_flags - product_version.permitted_build_flags

    invalid_flags.each do |f|
      errors.add(:flags, "#{f} is not a valid flag")
    end

    forbidden_flags.each do |f|
      errors.add(:flags, "#{f} is not allowed for #{product_version.name}")
    end

    if (added_flags|removed_flags).include?('buildroot-push') && errata && !errata.allow_edit?
      errors.add(:flags, "buildroot-push may not be modified when advisory status is #{errata.status}")
    end

    if added_flags.include?('buildroot-push') && brew_archive_type.present?
      errors.add(:flags, 'buildroot-push is only applicable for RPMs')
    end
  end

  def invalidate_external_test_runs
    external_test_runs.active.each(&:make_inactive!)
  end
end
