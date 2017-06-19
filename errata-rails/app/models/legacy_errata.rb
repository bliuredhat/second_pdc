#
# Parent class for all non-PDC advisories
#
class LegacyErrata < Errata
  has_many_files :legacy_current_files, :errata_files, :version_id

  has_many :errata_brew_mappings,
  :foreign_key => :errata_id,
  :conditions => Proc.new {
    cond = 'current = 1'
    # may be called from join association instead of Errata instance
    cond += " AND errata_id = #{id}" if defined?(id) && id
    # double sub-query to work around mysql performance issues
    %{
        errata_brew_mappings.id IN (
          SELECT * FROM (
            SELECT MAX(id) AS id
            FROM errata_brew_mappings WHERE #{cond}
            GROUP BY errata_id, brew_build_id, product_version_id, build_tag,
              package_id, current, spin_version, shipped, brew_archive_type_id
          ) AS sq
        )
      }
  },
  :include => [:product_version, :brew_build, :package]
  
  has_many :brew_builds, :through => :errata_brew_mappings, :uniq => true

  has_many :packages, :through => :errata_brew_mappings, :uniq => true


  has_many :product_versions, :through => :errata_brew_mappings, :uniq => true
  # Same as product_versions, define it for duck typing with PdcErrata
  has_many :release_versions, :through => :errata_brew_mappings, :uniq => true,
    :class_name => 'ProductVersion'

  def self.build_mapping_class
    ErrataBrewMapping
  end

  # (Try not to use this too much.)
  def is_pdc?
    false
  end

  def is_legacy?
    true
  end

  # For want of a better name use the term "release_variant"
  # to mean either a variant or a pdc_variant.
  def release_variants
    variants
  end

  def release_versions_used_by_advisory
    product_versions_used_by_advisory
  end

  def errata_type_valid
    errors.add(:release, "is_pdc must be false") if release.present? and release.is_pdc?
  end

  def build_mappings
    errata_brew_mappings
  end

  def build_mapping_class
    self.class.build_mapping_class
  end

  private

  def product_versions_used_by_advisory
    return product_versions unless text_only?
    pvs = text_only_channel_list.
      get_all_channel_and_cdn_repos.
      map(&:product_version).
      uniq
    pvs = product.product_versions if pvs.empty?
    pvs
  end

end
