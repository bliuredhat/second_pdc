class FtpExclusion < ActiveRecord::Base
  belongs_to :package
  belongs_to :product
  belongs_to :product_version

  scope :for_package, lambda { |package|
    where 'ftp_exclusions.package_id = ?', package
  }

  scope :product_based,         where('product_version_id IS NULL')
  scope :product_version_based, where('NOT product_version_id IS NULL')

  #-----------------------------------------------------------------------
  # We have slightly non-normalised data, but that's okay. Make sure product_id
  # has a sensible value. (Might have been nicer to have separate tables
  # for product exclusions and product_version exclusions)
  before_create do
    self.product ||= self.product_version.product
  end

  validate do
    # Prevent duplicates. (Did it this way because of the NULLs.
    # Maybe validates_uniqueness_of could do it. Not sure...)

    ## For some reason when we run tests the fixtures get loaded twice (or something)
    ## and it spits out validation errors here. So disable this validation for testing
    ## only. TODO: figure out why this happens and fix it properly.
    return if Rails.env.test?

    if product_version_id
      errors.add(:package_id, "already has this exclusion") if FtpExclusion.exists?([
        'package_id = ? AND product_version_id = ?', package_id, product_version_id
      ])
    else
      errors.add(:package_id, "already has this exclusion") if FtpExclusion.exists?([
        'package_id = ? AND product_id = ? AND product_version_id IS NULL', package_id, product_id
      ])
    end
  end

  #-----------------------------------------------------------------------
  # Methods used by is_excluded?
  #
  # Separating them out for readability and so we can make a report showing
  # exactly why something is excluded.
  #
  # Keeping the arguments consistent in each method even though they aren't
  # always both used.

  # Excluded because product.allow_ftp? is false
  def self.exclude_by_product?(package,product_version)
    !product_version.product.allow_ftp?
  end

  # Excluded because product_version.forbid_ftp? is true
  def self.exclude_by_prod_ver?(package, product_version)
    product_version.forbid_ftp?
  end

  # Excluded because an FtpExclusion record exists for this package and product_version
  def self.exclude_by_pkg_and_prod_ver?(package, product_version)
    FtpExclusion.exists?(['package_id = ? AND product_version_id = ?', package, product_version])
  end

  # Excluded because an FtpExclusion record exists for this package and product
  def self.exclude_by_pkg_and_product?(package, product_version)
    FtpExclusion.exists?(['package_id = ? AND product_id = ? AND product_version_id IS NULL', package, product_version.product])
  end

  #
  # Excluded because of RHEL release rules
  #
  # "starting with RHEL5.7 and 6.2 we should not post the srpms on the public ftp site"
  # See https://bugzilla.redhat.com/show_bug.cgi?id=716503
  #
  # This is a quick fix to meet the requirements.
  # Hopefully will be refactored into a cleaner and better system for
  # managing publishing rules.
  #
  # See lib/tasks/debug_ftp_excl_rules
  #
  def self.exclude_by_rhel_release_rules?(package, product_version)
    (
      # It is RHEL
      product_version.product.short_name == 'RHEL' &&

      # Product version has the same name as a RhelRelease
      # (Confusing, huh... Any better way to do this?)
      RhelRelease.find_by_name(product_version.name).present? &&

      # And either:
      (
        # RHEL-X where X is 5 or higher
        (product_version.name =~ /^RHEL-(\d+)$/ && $1.to_i == 5) || # <-- prior to RHEL-6.2 coming out
        #(product_version.name =~ /^RHEL-(\d+)$/ && $1.to_i >= 5) || # <-- change to this when RHEL-6.2 comes out

        # RHEL-5.Y.Z where Y is 7 or higher
        (product_version.name =~ /^RHEL-5\.(\d+)\.$/ && $1.to_i >= 7) ||

        # RHEL-6.Y.Z where Y is 2 or higher
        (product_version.name =~ /^RHEL-6\.(\d+)\.$/ && $1.to_i >= 2)
      ) &&

      # And the package begins with redhat-release but not redhat-release-notes
      (package.name =~ /^redhat-release/ && package.name !~ /^redhat-release-notes/)
    )
  end


  #
  # Is this package/product_version combination excluded from
  # publishing SRPMS on the public ftp?
  #
  def self.is_excluded?(package, release_version)
    # For now we'll assume no ftp exclusions for PDC advisories
    return false if release_version.is_pdc?

    (
      self.exclude_by_product?(            package, release_version ) ||
      self.exclude_by_prod_ver?(           package, release_version ) ||
      self.exclude_by_pkg_and_prod_ver?(   package, release_version ) ||
      self.exclude_by_pkg_and_product?(    package, release_version ) ||
      self.exclude_by_rhel_release_rules?( package, release_version )
    )
  end

  #
  # This is for reporting only.
  # Used in FtpExclusionController#lookup_package_exclusions
  # and also lib/tasks/debug_ftp_excl_rules
  #
  def self.exclude_reasons(package, product_version)
    show_detail = [
      [:exclude_by_product?,            'product'                 ],
      [:exclude_by_prod_ver?,           'product version'         ],
      [:exclude_by_pkg_and_prod_ver?,   'package/product version' ],
      [:exclude_by_pkg_and_product?,    'package/product'         ],
      [:exclude_by_rhel_release_rules?, 'RHEL release rules'      ],
    ].map do |method, reason_text|
      reason_text if self.send(method, package, product_version)
    end.compact
  end

  def self.show_exclude_rules(package, product_version)
    self.exclude_reasons(package, product_version).join(', ')
  end

end
