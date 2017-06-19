# == Schema Information
#
# Table name: pdc_released_packages
#
#  id                 :integer       not null, primary key
#  pdc_variant_id     :integer       not null
#  package_id         :integer       not null
#  arch_id            :integer       not null
#  full_path          :string        not null
#  pdc_release_id     :integer       not null
#  current            :integer       default(1)
#  updated_at         :datetime
#  rpm_name           :string
#  brew_rpm_id        :integer
#  brew_build_id      :integer
#  created_at         :datetime
#  errata_id          :integer
#
require 'trie'

class PdcReleasedPackage < ActiveRecord::Base
  include ReleasedPackageCommon

  include SqlExtension

  belongs_to :pdc_variant
  belongs_to :pdc_release

  validates_presence_of :pdc_release, :brew_build, :package, :arch, :full_path, :pdc_variant

  class << self

    # Finds the latest released package for the given mapping
    #
    # @param mapping [PdcErrataReleaseBuild]
    # @return [PdcReleasedPackage,nil]
    def latest_for_build_mapping(mapping)
      current.where(package_id: mapping.package,
                    pdc_release_id: mapping.pdc_release).first

    end

    def make_released_packages_for_errata(errata)
      raise "Advisory is not in SHIPPED_LIVE" unless errata.status == State::SHIPPED_LIVE

      ActiveRecord::Base.transaction do
        package_attrs = []

        # These calculate the released packages accurately, based on what would be
        # pushed where, according to product listings, active repos & push
        # targets, etc.
        package_attrs.concat(attrs_from_rhn(errata))
        package_attrs.concat(attrs_from_cdn(errata))

        errata.build_mappings.for_rpms.each(&:release!)

        update = ReleasedPackageUpdate.create!(
          :who => User.system,
          :reason => "Generated for advisory #{errata.advisory_name}",
          :user_input => {}
        )
        rp = released_packages_from_attrs!(package_attrs)
        update.pdc_released_packages = rp
        rp
      end
    end

    # Returns previously released packages for the given pdc_variant(s), arch, and
    # RPMs.
    #
    # The arch here is the arch of a repo where the package was shipped, which is
    # not necessarily equal to the arch of an RPM.  For example, if the_arch is
    # s390x, the found packages may include RPMs with arches noarch, s390 and
    # s390x, since all of those can be shipped to an s390x repo.
    def last_released_packages_by_variant_and_arch(the_variant, the_arch, brew_rpms, opts = {})
      the_variants = Array.wrap(the_variant).uniq
      released_packages = current.where(:pdc_variant_id => the_variants, :arch_id => the_arch).for_brew_rpms(brew_rpms)
      _get_last_released_packages(released_packages, brew_rpms, the_variants, opts)
    end

    private

    def attrs_from_mapping(map)
      out = []
      map.build_product_listing_iterator do |brew_file, variant, brew_build, arch_list|
        arch_list.each do |arch|
          out << {
            :pdc_variant => variant,
            :arch => arch,
            :package => brew_build.package,
            :brew_build => brew_build,
            :brew_rpm => brew_file,
            :full_path => brew_file.file_path,
            :errata => map.errata,
            :pdc_release => map.pdc_release
          }
        end
      end
      out
    end

    def release_version
      :pdc_release
    end

    def attrs_from_push_map(errata, out)
      lambda do |brew_build, rpm, _, arch, targets, mapped_targets|
        (targets + mapped_targets).each do |target|
          out << {
            :pdc_variant => PdcVariant.get_by_release_and_variant(target.release_id, target.variant_uid),
            :pdc_release => PdcRelease.get(target.release_id),
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
  end
end
