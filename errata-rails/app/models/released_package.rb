# == Schema Information
#
# Table name: released_packages
#
#  id                 :integer       not null, primary key
#  version_id         :integer       not null
#  package_id         :integer       not null
#  arch_id            :integer       not null
#  full_path          :string        not null
#  product_version_id :integer       not null
#  current            :integer       default(1)
#  updated_at         :datetime
#  rpm_name           :string
#  brew_rpm_id        :integer
#  brew_build_id      :integer
#  created_at         :datetime
#
require 'trie'

class ReleasedPackage < ActiveRecord::Base
  include ReleasedPackageCommon

  # FIXME: Keeping this only prevent failures in sql_extention_test
  include SqlExtension

  belongs_to :variant,
  :foreign_key => "version_id"
  belongs_to :product_version

  validates_presence_of :product_version, :brew_build, :package

  # Finds the latest released package for the given mapping
  #
  # @param mapping [ErrataBrewMapping]
  # @return [ReleasedPackage,nil]
  def self.latest_for_build_mapping(mapping)
    current.where(package_id: mapping.package,
                  product_version_id: mapping.product_version).first
  end

  # Returns previously released packages for the given variant(s), arch, and
  # RPMs.
  #
  # The arch here is the arch of a repo where the package was shipped, which is
  # not necessarily equal to the arch of an RPM.  For example, if the_arch is
  # s390x, the found packages may include RPMs with arches noarch, s390 and
  # s390x, since all of those can be shipped to an s390x repo.
  def self.last_released_packages_by_variant_and_arch(the_variant, the_arch, brew_rpms, opts = {})
    the_variants = Array.wrap(the_variant).uniq

    released_packages = current.where(:version_id => the_variants, :arch_id => the_arch).for_brew_rpms(brew_rpms)
    _get_last_released_packages(released_packages, brew_rpms, the_variants, opts)
  end

  def self.get_released_packages(package_name,
                                 product_version_name,
                                 filter = { })
    package = Package.find_by_name(package_name)
    pv = ProductVersion.find_by_name(product_version_name)

    return ReleasedPackage.find(:all, :conditions => ['current = 1 and package_id = ? and product_version_id = ?', package, pv])


  end

  def self.make_released_packages_for_build(nvr, product_version, rp_update, opts = {})
    use_product_listing_cache = opts.fetch(:use_product_listing_cache, false)

    brew_build = BrewBuild.make_from_rpc(nvr)

    ProductListing.find_or_fetch(product_version, brew_build, :use_cache => use_product_listing_cache)
    map = ErrataBrewMapping.find(:first,
                                 :conditions => ['product_version_id = ? and brew_build_id = ? and shipped = 1',
                                                 product_version,
                                                 brew_build])
    unless map
      map = ErrataBrewMapping.new(:product_version => product_version,
                                  :brew_build => brew_build)
    end

    ActiveRecord::Base.transaction do
      attrs = attrs_from_mapping(map)
      rp = released_packages_from_attrs!(attrs, opts)
      rp_update.add_released_packages(rp)
    end
  end

  def self.make_released_packages_for_errata(errata)
    raise "Advisory is not in SHIPPED_LIVE" unless errata.status == State::SHIPPED_LIVE

    ActiveRecord::Base.transaction do
      package_attrs = []

      # These calculate the released packages accurately, based on what would be
      # pushed where, according to product listings, active repos & push
      # targets, etc.
      package_attrs.concat(attrs_from_rhn(errata))
      package_attrs.concat(attrs_from_cdn(errata))

      # We also calculate released packages just from the errata brew mappings.
      # This follows product listings, but not active repos & push targets and
      # other settings. Thus it's less accurate.
      #
      # We filter by the RPMs and arches really pushed to RHN/CDN to make it a
      # little more accurate.
      #
      # Why not just drop this altogether? That was attempted, but it turns out
      # to have unintended side-effects.
      #
      # In particular, those attrs_from_{rhn,cdn} methods record released
      # package records against the variant which a channel/repo "belongs to"
      # (and not "is linked to"), while attrs_from_mappings uses the variants on
      # the product version for which the build was added to the advisory.
      # These can be different in some cases. Pending a larger refactor of
      # released packages, we want to keep recording both sets of variants.
      #
      # See bug 1259086.
      attr_key = lambda{ |x| x.slice(:brew_rpm, :arch) }
      keep_keys = package_attrs.map(&attr_key).uniq
      mapping_attrs = attrs_from_mappings(errata).
                      select{ |x| keep_keys.include?(attr_key[x]) }

      package_attrs.concat(mapping_attrs)

      errata.build_mappings.for_rpms.each(&:release!)
      errata.build_mappings.tar_files.select(&:has_docker?).each(&:release!)

      update = ReleasedPackageUpdate.create!(
        :who => User.system,
        :reason => "Generated for advisory #{errata.advisory_name}",
        :user_input => {}
      )
      rp = released_packages_from_attrs!(package_attrs)
      update.released_packages = rp
      rp
    end
  end

  #
  # Based loosely on some code from RpmdiffRun#set_old_version
  # Going to use this for creating cov scans.
  #
  def self.get_previously_released_nvr(errata_brew_mapping)
    previous_packages = ReleasedPackage.
      current.
      where(:package_id => errata_brew_mapping.brew_build.package).
      where(:product_version_id => errata_brew_mapping.product_version).
      order('id desc')

    if previous_packages.any?
      previous_packages.first.brew_build.nvr
    else
      # TODO: This is what rpmdiff does.
      # Not sure if Covscan will be able to deal with this.
      'NEW_PACKAGE'
    end
  end

  private

  def brew_build_version
    return unless errors.blank?

    released_packages = ReleasedPackage.
      current.
      select("distinct brew_build_id").
      where(:product_version_id => self.product_version_id, :package_id => self.package_id)

    return if released_packages.empty?

    latest_brew_build = released_packages.
      sort{ |a,b| a.brew_build.compare_versions(b.brew_build) }.
      last.
      brew_build

    new_brew_build = self.brew_build
    # Should be ok to allow equal version. There is a case where new advisory has
    # different product listings with the shipped advisory
    if latest_brew_build.is_newer?(new_brew_build)
      errors.add(:brew_build, "'#{new_brew_build.nvr}' is older than the latest released brew build '#{latest_brew_build.nvr}'.")
    end
  end

  def self.release_version
    :product_version
  end

  def self.released_packages_from_attrs!(attrs, opts = {})
    check_version = opts.fetch(:check_brew_build_version, false)

    out = []
    attrs.uniq.group_by{|x| x.slice(:product_version, :package,
                                    :brew_build, :variant, :arch, :brew_rpm
                                   )}
      .each do |key,these_attrs|

      flag_as_outdated = ReleasedPackage.includes(:brew_rpm)
                           .current
                           .where("released_packages.brew_build_id != #{key[:brew_build].id}")
                           .where(
                             :product_version_id => key[:product_version],
                             :package_id => key[:package],
                             :version_id => key[:variant],
                             :arch_id => key[:arch]
                           )
                           .where("brew_files.arch_id = #{key[:brew_rpm].arch_id}")
                           .where("brew_files.name REGEXP '^#{key[:brew_rpm].name_nonvr}-([^-]+)-([^-]+)$'")
                           .map(&:id)

      ReleasedPackage.transaction do
        these_attrs.each do |x|
          out << ReleasedPackage.create!(x.merge(:check_brew_build_version => check_version))
        end
        ReleasedPackage.where(:id => flag_as_outdated).update_all(:current => false)
      end
    end
    out
  end

  def self.attrs_from_mappings(errata)
    out = []
    errata.build_mappings.for_rpms.each do |map|
      out.concat(attrs_from_mapping(map))
    end
    out
  end

  def self.attrs_from_push_map(errata, out)
    lambda do |brew_build, rpm, _, arch, targets, mapped_targets|
      (targets + mapped_targets).each do |target|
        out << {
          :variant => target.variant,
          :product_version => target.product_version,
          :arch => arch,
          :package => brew_build.package,
          :brew_build => brew_build,
          :brew_rpm => rpm,
          :full_path => rpm.file_path,
          :errata => errata
        }
      end
    end
  end

  def self.attrs_from_mapping(map)
    attrs = _attrs_from_mapping(map)
    product_version = map.product_version
    if product_version.product.is_rhel? && product_version.is_zstream? && !product_version.is_eus_aus?
      base_map = ErrataBrewMapping.new(:product_version => product_version.main_stream_product_version!,
                                  :brew_build => map.brew_build)
      attrs.concat _attrs_from_mapping(base_map)
    end
    attrs
  end

  def self._attrs_from_mapping(map)
    out = []
    map.build_product_listing_iterator do |rpm,variant, brew_build, arch_list|
      arch_list.each do |arch|
        out << {
          :variant => variant,
          :product_version => map.product_version,
          :arch => arch,
          :package => brew_build.package,
          :brew_build => brew_build,
          :brew_rpm => rpm,
          :full_path => rpm.file_path,
          :errata => map.errata
        }
      end
    end
    out
  end
end
