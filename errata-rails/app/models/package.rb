# == Schema Information
#
# Table name: packages
#
#  id         :integer       not null, primary key
#  name       :string(255)   not null
#  created_at :datetime      not null
#

class Package < ActiveRecord::Base
  include FindByIdOrName

  has_many :brew_builds
  has_many :bugs
  has_many :errata_brew_mappings, :conditions => {:current => 1}
  has_many :errata, :through => :errata_brew_mappings, :order => 'created_at DESC'
  has_many :release_components
  has_many :package_restrictions, :dependent => :destroy
  has_many :push_targets, :through => :package_restrictions, :dependent => :destroy
  has_many :cdn_repo_packages, :dependent => :destroy
  has_many :cdn_repos, :through => :cdn_repo_packages

  has_many :multi_product_channel_maps, :dependent => :restrict
  has_many :multi_product_cdn_repo_maps, :dependent => :restrict

  belongs_to :docs_responsibility
  belongs_to :quality_responsibility
  belongs_to :devel_responsibility
  
  belongs_to :devel_owner,
  :class_name => "User",
  :foreign_key => 'devel_owner_id'

  belongs_to :qe_owner,
  :class_name => "User",
  :foreign_key => 'qe_owner_id'

  before_create do
    self.qe_owner ||= User.find_by_login_name('qa-dept-list@redhat.com ')
    self.devel_owner ||= User.find_by_login_name('ship-list@redhat.com ')
    self.quality_responsibility ||= QualityResponsibility.find_by_name('Default')
    self.docs_responsibility ||= DocsResponsibility.find_by_name('Default')
    self.devel_responsibility ||= DevelResponsibility.find_by_name('Default')
  end
  
  def self.make_from_name(package_name)
    name = package_name.strip
    package = Package.find_by_name(name)
    unless package
      package = Package.new(:name => name)
      package.save
    end
    return package
  end

  def to_s
    return name
  end
  
  def url_name
    return name
  end

  #
  # Use this for sorting in DocsController#doc_text_info
  # Docs and Guides are supposed to appear last in the Advisory
  # release notes.
  #
  def name_sort_with_docs_last
    case name
    when /^doc|^guide|guide$/i
      "ZZ-#{name}"
    else
      "AA-#{name}"
    end
  end

  # Returns a nested hash of package_id vs another (inner) hash of
  # restricted variant vs supported push types. The inner hash will be
  # empty if a package id has no restrictions
  def self.prepare_cached_package_restrictions(package_ids)
    # This can work with has_key?
    restrictions = Hash.new { |h, k| h[k] = {} }

    PackageRestriction.
      includes(:push_targets).
      where(:package_id => package_ids).each do |r, _|
        restrictions[r.package_id][r.variant_id] = r.supported_push_types
      end

    # ensure all package_id have an entry in the hash. Set inner hash to an empty
    # hash if there aren't any restrictions
    package_ids.each { |id| restrictions[id] }
    restrictions
  end

  def supported_push_types_by_variant(variant)
    cached = ThreadLocal.get(:cached_restrictions)
    if cached && cached.has_key?(self.id)
      return cached[self.id][variant.id] if cached[self.id].has_key?(variant.id)
    else
      restriction = package_restrictions.find_by_variant_id(variant)
      # Return the restricted push types of the package
      return restriction.supported_push_types if restriction
    end

    # If the package has no restriction, then return all available push types of the variant.
    return variant.supported_push_types
  end

  def supports_cdn?(variant)
    supported_push_types_by_variant(variant).select{|push_type| [:cdn, :cdn_stage].include?(push_type)}.any?
  end

  def supports_rhn?(variant)
    supported_push_types_by_variant(variant).select{|push_type| [:rhn_live, :rhn_stage].include?(push_type)}.any?
  end

  def self.find_or_create_packages!(components)
    return {} if components.empty?

    bug_components = components.uniq
    packages = Package.where(:name => bug_components).each_with_object({}) do |package, hash|
      hash[package.name] = package
    end

    missing_packages = bug_components - packages.keys
    missing_packages.each do |missing_package|
      packages[missing_package] = Package.create!(:name => missing_package)
    end
    return packages
  end

  def self.for_nvr(nvr)
    if nvr =~ /^(.+)-[^-]+-[^-]+$/
      Package.find_by_name($1)
    end
  end
end
