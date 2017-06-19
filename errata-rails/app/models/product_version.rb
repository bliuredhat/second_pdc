# == Schema Information
#
# Table name: product_versions
#
#  id               :integer       not null, primary key
#  product_id       :integer       not null
#  name             :string        not null
#  description      :string
#  default_brew_tag :string
#  rhel_release_id  :integer
#  sig_key_id       :integer       not null
#

class ProductVersion < ActiveRecord::Base
  require 'brew'

  include FindByIdOrName
  include CanonicalNames
  include TimidUpdateAttribute

  extend Memoist
  serialize :unused_push_types, Array
  serialize :permitted_build_flags, Set

  belongs_to :product
  belongs_to :rhel_release
  belongs_to :sig_key
  belongs_to :base_product_version,
  :class_name => 'ProductVersion'

  has_many :variants,
  :conditions => {:enabled => true}

  has_many :channels,
  :include => [:arch, :variant],
  :through => :variants
  has_many :channel_links,
  :through => :variants,
  :include => :channel

  has_many :active_channels,
  :through => :channel_links,
  :source => :channel

  has_many :cdn_repos,
  :through => :variants

  has_many :cdn_repo_links,
  :through => :variants

  has_many :active_repos,
  :through => :cdn_repo_links,
  :source => :cdn_repo
  alias_method :active_cdn_repos, :active_repos

  has_many :errata_brew_mappings,
  :conditions => {:current => true}

  has_many :errata,
  :through => :errata_brew_mappings,
  :uniq => true

  has_and_belongs_to_many :releases

  # call destroy instead of delete
  has_many :active_push_targets, :dependent => :destroy
  has_many :push_targets,
  :through => :active_push_targets, :dependent => :destroy

  has_many :released_packages,
    :conditions => {:current => true}

  has_many :released_brew_builds,
    :through => :released_packages,
    :source => :brew_build,
    :class_name => 'BrewBuild',
    :uniq => true

  has_many :brew_tags_product_versions
  has_many :brew_tags, :through => :brew_tags_product_versions
  validates_presence_of :name, :rhel_release, :sig_key, :product
  validates_uniqueness_of :name
  validate :sig_key_valid?
  validate :base_product_valid?
  validates_uniqueness_of :base_product_version_id,
  :allow_nil => true
  validate :rhel_release_matches_variants

  scope :valid_base_products, :conditions => "name in ('RHEL-4', 'RHEL-5', 'RHEL-6', 'RHEL-7')"

  scope :enabled, where('enabled = 1')

  scope :with_active_product, joins(:product).where(:errata_products => { :isactive => true }).order('product_versions.name')

  def self.find_active
    self.with_active_product
  end

  def self.exclude_ids(id_list)
    # self.scoped means do nothing but return the right class for chaining AREL scopes
    id_list.empty? ? self.scoped : self.where("product_versions.id NOT IN (?)", id_list)
  end

  before_save do
    # Can't have a RHEL product version be an addon to itself
    self.is_rhel_addon = false if self.product.is_rhel?
    true
  end

  after_save do
    # In before save, push_targets are not yet updated so we have to set these here.
    # (Use 'timid' update to avoid infinite callback loop).
    # (Todo: maybe we should drop these columns and just derive the values)
    timid_update_attribute(:supports_cdn, supports_push_type?(:cdn))
    timid_update_attribute(:forbid_ftp, !supports_push_type?(:ftp))
    true
  end

  def is_pdc?
    false
  end

  def get_product_listings(brew_build,
                           trace = lambda { |msg| logger.debug(msg)} )
    return ProductListing.find_or_fetch(self, brew_build, :trace => trace)
  end

  def forbid_rhn_debuginfo?
    !self.allow_rhn_debuginfo?
  end

  def rhel_variants

    return Variant.find(:all,
                        :conditions => ['rhel_release_id = ? and id = rhel_variant_id',
                                        rhel_release])

  end

  def rhel_version_number
    vn = rhel_release.version_number
    vn = '2.1' if vn == 2
    vn.to_s
  end

  # Returns true if composedb uses split product listings
  #
  # This means that a separate getProdutListings call must be made,
  # merging the product version name with the rhel variant name
  # of each variant.
  #
  # Example: To get the listings for product version RHEL-6-RHNTOOLS
  #          and build jabberpy-0.5-0.21.el6sat
  #
  # brew call getProductListings RHEL-6-Client-RHNTOOLS  jabberpy-0.5-0.21.el6sat
  #   {'RHNTools': {'jabberpy-0.5-0.21.el6sat': {'noarch': ['x86_64', 'i386'],
  #         'src': ['x86_64', 'i386']}}}
  # brew call getProductListings RHEL-6-Server-RHNTOOLS  jabberpy-0.5-0.21.el6sat
  #   {'RHNTools': {'jabberpy-0.5-0.21.el6sat': {'noarch': ['x86_64',
  #                                                       'i386',
  #                                                       'ppc64',
  #                                                       's390x'],
  #                                            'src': ['x86_64',
  #                                                    'i386',
  #                                                    'ppc64',
  #           's390x']}}}
  # brew call getProductListings RHEL-6-ComputeNode-RHNTOOLS  jabberpy-0.5-0.21.el6sat
  #   {'RHNTools': {'jabberpy-0.5-0.21.el6sat': {'noarch': ['x86_64'],
  #         'src': ['x86_64']}}}
  # brew call getProductListings RHEL-6-Workstation-RHNTOOLS  jabberpy-0.5-0.21.el6sat
  #   {'RHNTools': {'jabberpy-0.5-0.21.el6sat': {'noarch': ['x86_64', 'i386'],
  #         'src': ['x86_64', 'i386']}}}
  #
  # Compared to a RHEL 4 product:
  #  brew call getProductListings RHEL-4-JBEWP-5 xml-security-1.5.1-3_patch01.ep5.el4
  # {'AS': {'xml-security-1.5.1-3_patch01.ep5.el4': {'noarch': ['x86_64',
  #                                                           'i386'],
  #       'src': ['x86_64', 'i386']}},
  #   'ES': {'xml-security-1.5.1-3_patch01.ep5.el4': {'noarch': ['x86_64',
  #                                                           'i386'],
  #       'src': ['x86_64', 'i386']}}}
  #
  def has_split_product_listings?
    [5,6].include? rhel_release.version_number
  end

  # Returns true if the getProductListings returns the full variant, or just
  # the RHEL variant. Example:
  #
  # brew call getProductListings RHEL-4-JBEWP-5 xml-security-1.5.1-3_patch01.ep5.el4
  #  {'AS': {'xml-security-1.5.1-3_patch01.ep5.el4': {'noarch': ['x86_64',
  #                                                            'i386'],
  #        'src': ['x86_64', 'i386']}},
  #    'ES': {'xml-security-1.5.1-3_patch01.ep5.el4': {'noarch': ['x86_64',
  #                                                            'i386'],
  #        'src': ['x86_64', 'i386']}}}
  #
  # Contrast with a RHEL 5 product
  # brew call getProductListings  RHEL-5-Server-JBEWP-5 xml-security-1.5.1-3_patch01.ep5.el5
  #   {'JBEWP-5': {'xml-security-1.5.1-3_patch01.ep5.el5': {'noarch': ['x86_64',
  #                                                                  'i386'],
  #                                                       'src': ['x86_64',
  #           'i386']}}}
  #
  def uses_full_variant_in_product_listings?
    [5,6,7].include? rhel_release.version_number
  end

  def is_at_least_rhel5?
    rhel_release.version_number >= 5
  end

  # Returns true if this is a zstream variant of a product. Currently only rhel4 has a zstream separate
  # from mainline.
  def is_zstream?
    return false unless rhel_release
    return rhel_release.is_zstream?
  end

  # Returns true if this is an extended support (EUS or AUS) product version.
  def is_eus_aus?
    return !!(rhel_release && rhel_release.name =~ /[A|E]US/)
  end

  # Returns the mapping of product labels for RHEL products where
  # RHEL is >= 5
  def product_mapping
    return { } unless self.has_split_product_listings?
    if self.name =~ /(RHEL-[0-9].?)(-.+)/
      prefix = $1
      suffix = $2
    else
      prefix = self.name
      suffix = ''
    end
    self.rhel_release.name =~ /(RHEL-[0-9])/
    rhel_pv = ProductVersion.find_by_name $1

    variants = Variant.find(:all,
                            :conditions =>
                            ['product_version_id = ? and id = rhel_variant_id',
                             rhel_pv])

    names = variants.collect {|v| v.name}.collect {|n| n[1..-1]}
    products = { }
    names.each do |n|
      products[n] = prefix + "-#{n}"
    end
    suffix = '-RHX' if suffix == '-RHX-Centric'

    if self.is_server_only?
      products.delete_if {|k,v| k != 'Server'}
    end

    products.each_pair { |k,v| products[k] = v + suffix}
    return products
  end

  def supports_push_type?(pt)
    push_targets.where(:push_type => pt).any?
  end

  def supports_ftp?
    supports_push_type? :ftp
  end

  def supports_rhn_live?
    supports_push_type? :rhn_live
  end

  def supports_rhn_stage?
    supports_push_type? :rhn_stage
  end

  def supports_rhn?
    supports_push_type?(:rhn_stage) || supports_push_type?(:rhn_live)
  end

  # allow_buildroot_push can be read/written like a boolean attribute,
  # but it's actually derived from the permitted_build_flags.
  def allow_buildroot_push
    permitted_build_flags.include?('buildroot-push')
  end
  alias_method :allow_buildroot_push?, :allow_buildroot_push

  def allow_buildroot_push=(value)
    oper = value.to_bool ? :add : :delete
    permitted_build_flags.send(oper, 'buildroot-push')
  end

  def version_rhel_map
    map = Hash.new
    variants.includes(:push_targets, :rhel_variant).each do |v|
      rhel_name = v.rhel_variant.name
      if uses_full_variant_in_product_listings?
        rhel_name = v.name
      end
      # Given how data comes back from brew, and the variant naming conventions,
      # Strip out the trailing Zstream naming bits.
      if is_zstream?
        list = rhel_name.split('-')
        list.pop
        rhel_name = list.join('-')
      end

      if (old_v = map[rhel_name])
        Rails.logger.warn(
          "Duplicates in version_rhel_map! For #{rhel_name}, overwriting: " +
          "#{old_v.name}, with: #{v.name}")
      end

      map[rhel_name] = v
    end
    return map
  end
  memoize :version_rhel_map

  def sig_key_valid?
    if self.sig_key == SigKey.none_key
      errors.add(:sig_key, "Need a valid Default Signing Key. Cannot be none.")
    end
  end

  def base_product_valid?
    return unless self.base_product_version
    unless self.is_zstream?
      errors.add(:base_product_version, 'Cannot set a base product version for a non-zstream product')
    end
  end

  # See also the `rhel_release_valid` validation for variants
  def rhel_release_matches_variants
    mismatched_variants = self.variants.select{ |v| v.rhel_release_id != self.rhel_release_id }
    unless mismatched_variants.empty?
      names = mismatched_variants.map(&:rhel_release).map(&:name).uniq
      errors.add(:rhel_release, "does not match that of variants: #{rhel_release.name} versus #{names.join(', ')}")
    end
  end

  def main_stream_product_version!
    ProductVersion.find_by_name!(rhel_release.main_stream)
  end

  def can_add_builds_as_released?(nvrs)
    return false if errors.any?
    brew_build_released_list = brew_build_and_latest_released_info_for_nvrs(nvrs)
    brew_build_released_list.each do |brew_build|
      released = BrewBuild.new(
        :epoch => brew_build.released_epoch,
        :version => brew_build.released_version,
        :release => brew_build.released_release,
        :nvr => brew_build.released_nvr
      )
      if RpmVersionCompare.rpm_version_compare(released, brew_build) == 1
        errors.add :brew_build, "'#{brew_build.nvr}' is older than the latest released brew build '#{released.nvr}'."
      end
    end
    errors.empty?
  end

  # Returns a list of brew_builds with additional information about released
  # builds (released_package.current = 1) for nvrs passed for the product_version
  # e.g. rhel_6.brew_build_and_latest_released_info_for_nvrs('abrt-2.0.8-9.el6') would return
  # [
  #  BrewBuild ( {
  #    "id"               => 239472,
  #    "nvr"              => "abrt-2.0.8-9.el6",
  #    "version"          => "2.0.8",
  #    "release"          => "9.el6",
  #    "epoch"            => nil,
  #
  #    "released_id"      => 441711,
  #    "released_nvr"     => "abrt-2.0.8-34.el6",
  #    "released_version" => "2.0.8",
  #    "released_release" => "34.el6",
  #    "released_epoch"   => nil
  #  }),
  # ]
  def brew_build_and_latest_released_info_for_nvrs(nvrs)
    input = BrewBuild.arel_table.alias(:input)
    released = BrewBuild.arel_table.alias(:released)
    package = Package.arel_table
    released_package = ReleasedPackage.arel_table
    product_version = ProductVersion.arel_table

    query = package.
      join(input).on(input[:package_id].eq(package[:id])).
      join(released_package).on(released_package[:package_id].eq(package[:id])).
      join(product_version).on(released_package[:product_version_id].eq(product_version[:id])).
      join(released).on(released_package[:brew_build_id].eq(released[:id])).
      where(
        released_package[:current].eq(1).
        and(product_version[:id].eq(id)).
        and(input[:nvr].in(Array.wrap(nvrs))).
        and(input[:nvr].not_eq(released[:nvr]))
      ).project(
        input[:id], input[:nvr], input[:version], input[:release], input[:epoch],
        released[:id].as('released_id'),
        released[:nvr].as('released_nvr'),
        released[:version].as('released_version'),
        released[:release].as('released_release'),
        released[:epoch].as('released_epoch'))
    # NOTE: has to be make uniq/distinct since released_packages table is not normalised
    query.distinct

    BrewBuild.find_by_sql(query.to_sql)
  end

  def short_name
    self.name
  end

  def verbose_name
    self.description
  end

  def display_name
    'Product Version'
  end
end
