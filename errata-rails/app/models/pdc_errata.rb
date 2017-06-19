#
# Parent class for all PDC advisories
#
class PdcErrata < Errata
  has_many_files :pdc_current_files, :pdc_errata_files, :pdc_variant_id

  has_many :pdc_errata_releases, :foreign_key => :errata_id

  has_many :pdc_releases, :through => :pdc_errata_releases
  has_many :release_versions, :class_name => :PdcRelease,
           :through => :pdc_errata_releases

  has_many :packages, :through => :pdc_errata_releases

  # NOTE: see note about build_mappings in errata.rb
  has_many :pdc_errata_release_builds, :conditions => {:current => 1},
           :through => :pdc_errata_releases,
           :include => [:pdc_errata_release, :brew_build]

  has_many :brew_builds, :through => :pdc_errata_release_builds

  def self.build_mapping_class
    PdcErrataReleaseBuild
  end

  # (Try not to use this too much.)
  def is_pdc?
    true
  end

  def is_legacy?
    false
  end

  def available_pdc_releases
    release.pdc_releases
  end

  #
  # Returns a list of nvrs for builds in this errata grouped by
  # pdc_release.
  #
  def build_nvrs_by_pdc_release
    pdc_errata_release_builds.each_with_object(HashSet.new) do |pdc_errata_release_build, builds_hash|
      builds_hash[pdc_errata_release_build.pdc_release] << pdc_errata_release_build.brew_build.nvr
    end
  end

  def build_files_by_nvr_variant_arch
    hsh = HashList.new

    pdc_errata_release_builds.each do |p|
      pdc_id = p.pdc_release.pdc_id
      build_info = Hash.new { |hash, key| hash[key] = {}}
      nvr = p.brew_build.nvr

      p.get_file_listing.each do |f|
        # Not sure if uid and name are always identical, so use uid
        build_info[nvr][f.variant.uid] ||= HashList.new
        build_info[nvr][f.variant.uid][f.arch] << f.brew_rpm.filename
      end
      hsh[pdc_id] << build_info
    end
    hsh
  end

  def has_rpms?
    if @has_rpms.nil?
      @has_rpms = brew_files_by_pdc_errata_release_builds(pdc_errata_release_builds.for_rpms).any?
    end
    @has_rpms
  end

  def brew_files_by_pdc_errata_release_builds(for_mappings = nil)
    for_mappings ||= pdc_errata_release_builds
    query = %{
      LEFT JOIN brew_files ON
        brew_files.brew_build_id = pdc_errata_release_builds.brew_build_id AND
        brew_files.brew_archive_type_id <=> pdc_errata_release_builds.brew_archive_type_id
    }
    for_mappings.joins(query)
  end

  # For want of a better name use the term "release_variant"
  # to mean either a variant or a pdc_variant.
  def release_variants
    pdc_variants
  end

  def release_versions_used_by_advisory
    pdc_releases
  end

  def errata_type_valid
    errors.add(:product, "must support PDC") if product && !product.supports_pdc?
    errors.add(:release, "is_pdc must be true") if release && !release.is_pdc?
  end

  def build_mappings
    pdc_errata_release_builds
  end

  def build_mapping_class
    self.class.build_mapping_class
  end
end
