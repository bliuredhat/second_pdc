#
# There are a lot of commonalities between ErrataBrewMapping and
# PdcErrataReleaseBuild so let's put shared code here to reduce
# duplication of code.
#
module BuildMappingCommon
  extend ActiveSupport::Concern

  included do
    @@file_struct ||= Struct.new(:variant, :arch, :package, :brew_rpm, :devel_file, :errata)

    attr_accessor :skip_rpm_version_validation

    serialize :flags, Set

    belongs_to :brew_build
    belongs_to :brew_archive_type

    belongs_to :added_index,
      :class_name => 'StateIndex',
      :foreign_key => 'added_index_id'

    belongs_to :removed_index,
      :class_name => 'StateIndex',
      :foreign_key => 'removed_index_id'

    scope :current, :conditions => { :current => true }

    scope :for_rpms, :conditions => "`#{table_name}`.`brew_archive_type_id` IS NULL"
    scope :for_nonrpms, :conditions => "`#{table_name}`.`brew_archive_type_id` IS NOT NULL"
    scope :tar_files, :conditions => { :brew_archive_type_id => BrewArchiveType::TAR_ID }

    has_many :brew_files,
      :through => :brew_build,
      :conditions => lambda { |*|
        cond = self.brew_archive_type_id.nil? ? ' IS NULL' : "=#{self.brew_archive_type_id}"
        "`brew_files`.`brew_archive_type_id`#{cond}" }

    validate :validate_rpm_versions_in_brew_build, :on => :create, :unless => lambda{|m| m.skip_rpm_version_validation || m.for_nonrpms?}
  end

  def get_file_listing(opts = {})
    brew_files = []

    # ErrataFile only stores id of an object. For example, errata_file.variant will
    # cause a sql query.
    set_file = lambda do |variant, arch, package, file, file_path, errata|
      @@file_struct.new(variant, arch, package, file, file_path, errata)
    end

    use_method = opts.fetch(:method, set_file)

    self.build_product_listing_iterator do |file, variant, brew_build, arch_list|
      if file.is_a?(BrewRpm) && (file.is_srpm? || file.is_noarch?)
        # For source and noarch rpms we ignore arch_list and use the file's arch
        brew_files << use_method.call(variant, file.arch, brew_build.package, file, file.file_path, self.errata)
      else
        arch_list.each do |dest_arch|
          brew_files << use_method.call(variant, dest_arch, brew_build.package, file, file.file_path, self.errata)
        end
      end
    end
    return brew_files
  end

  def for_rpms?
    brew_archive_type_id.nil?
  end

  def for_nonrpms?
    !for_rpms?
  end

  # file type string used in some APIs and UIs
  def file_type_name
    self.brew_archive_type.try(:name) || 'rpm'
  end

  def errata_file_class
    is_pdc? ? PdcErrataFile : ErrataFile
  end

  def product_listing_class
    is_pdc? ? PdcProductListing : ProductListing
  end

  def errata_files
    errata_file_class.for_build_mapping(self)
  end

  def invalidate_files
    errata_files.current.update_all(:current => false, :prior => true)
  end

  def obsolete!
    return unless self.current?
    logger.debug "Obsoleting build mapping #{self.class} #{self.id}"
    self.current = 0
    self.removed_index = self.errata.current_state_index
    errata_file_class.transaction do
      self.save!
      invalidate_files
      invalidate_external_test_runs
    end
  end

  def reload_files
    return unless self.current?
    logger.debug "Reloading map #{self.class} #{self.id}"

    brew_build.import_files_from_rpc
    self.product_listing_class.find_or_fetch(release_version, brew_build, :use_cache => false)
    self.added_index = self.errata.current_state_index

    # TODO: Support this for pdc also (Bug 1441037)
    unless is_pdc?
      self.product_listings_mismatch_ack = false
    end

    self.class.transaction do
      self.save!
      invalidate_files
      make_new_file_listing
    end
  end

  def release!
    ActiveRecord::Base.transaction do
      self.shipped = 1
      self.brew_build.released_errata = self.errata

      self.brew_build.save!
      self.save!
    end
  end

  def make_new_file_listing
    return unless self.current? && self.for_rpms?
    logger.debug "New file listing for map #{self.class} #{self.id}"

    set_errata_file = lambda do |variant, arch, package, rpm, file_path, errata|
      errata_file_class.new(
        :variant    => variant,
        :arch       => arch,
        :package    => package,
        :brew_rpm   => rpm,
        :devel_file => file_path,
        :errata     => errata)
    end

    files = get_file_listing(:method => set_errata_file)

    # No transaction here since we should be already in one
    files.each(&:save!)
  end

  # Not sure if there is a better way to do this...
  def has_debuginfo_rpm?
    self.build_product_listing_iterator do |rpm, variant, brew_build, arch_list|
      return true if rpm.is_debuginfo?
    end
    false
  end

  # Some helpers to hopefully make code that needs to load a build mapping
  # tidier. They don't really belong here but this seems like an okay place
  # to keep them.

  def self.choose_mapping_class(opts={})
    if opts[:pdc] || opts[:is_pdc]
      PdcErrataReleaseBuild
    else
      ErrataBrewMapping
    end
  end

  def self.find(prod_ver_or_pdc_rel_id, opts={})
    choose_mapping_class(opts).find_by_id(prod_ver_or_pdc_rel_id)
  end

  def self.find_by_id(prod_ver_or_pdc_rel_id, opts={})
    choose_mapping_class(opts).find_by_id(prod_ver_or_pdc_rel_id)
  end

  module ClassMethods
    def added_at_index(state_index)
      where(:added_index_id => state_index).includes(:brew_build)
    end

    def dropped_at_index(state_index)
      where(:removed_index_id => state_index).includes(:brew_build)
    end
  end

end
