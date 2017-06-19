class CdnRepo < ActiveRecord::Base
  include ModelChild
  include NamedAttributes
  include FindByIdOrName
  include CanonicalNames
  include ModelDist
  include TpsTests
  belongs_to :variant
  belongs_to :arch

  # pretty sure this is correct. Let me know if not
  has_many :cdn_repo_links, :dependent => :destroy
  alias_attribute :links, :cdn_repo_links
  alias_attribute :use_for_tps, :has_stable_systems_subscribed
  alias_attribute :content_type, :type

  has_one :product_version, :through => :variant
  has_many :cdn_repo_packages, :dependent => :destroy
  has_many :packages, :through => :cdn_repo_packages

  has_many :multi_product_mapped_origin_cdn_repos,
           :class_name => 'MultiProductCdnRepoMap',
           :foreign_key => :origin_cdn_repo_id,
           :dependent => :restrict
  has_many :multi_product_mapped_destination_cdn_repos,
           :class_name => 'MultiProductCdnRepoMap',
           :foreign_key => :destination_cdn_repo_id,
           :dependent => :restrict

  validates_uniqueness_of :name
  validates :name, :presence => true
  validate :valid_name_format, :valid_type
  validates_presence_of :arch, :variant
  validate :package_mappings_supported

  CONTENT_TYPES = %w[CdnBinaryRepo CdnDebuginfoRepo CdnSourceRepo CdnDockerRepo]
  RELEASE_TYPES = %w[PrimaryCdnRepo EusCdnRepo FastTrackCdnRepo LongLifeCdnRepo]
  DEFAULT_RELEASE_TYPE = RELEASE_TYPES.first
  validates_inclusion_of :release_type, :in => RELEASE_TYPES, :message => "is not one of (#{RELEASE_TYPES.join(', ')})."

  before_validation(:on => :create) do
    self.release_type ||= DEFAULT_RELEASE_TYPE
  end

  after_destroy do
    # Destroying a repo can affect the set of valid TPS jobs, so
    # regenerate tps.txt soon
    TpsQueue.schedule_publication
  end

  named_attributes :arch, :variant

  scope :disabled, includes(:cdn_repo_links).where('cdn_repo_links.cdn_repo_id IS NULL')
  scope :enabled,  includes(:cdn_repo_links).where('cdn_repo_links.cdn_repo_id IS NOT NULL')

  def self.inherited(child)
    child.instance_eval do
      def model_name
        CdnRepo.model_name
      end

      def display_name
        CdnRepo.display_name
      end
    end
    super
  end

  after_create do
    CdnRepoLink.create(:cdn_repo => self,
                       :product_version => self.variant.product_version,
                       :variant => self.variant)
  end

  def cdn_content_set
    name.partition("__")[0]
  end

  # TPS expects to see "2.0" instead of "2_DOT_0" in its repo name field
  def cdn_content_set_for_tps
    cdn_content_set.gsub(/(\d)_DOT_(\d)/, '\1.\2')
  end

  def is_binary_repo?
    is_a?(CdnBinaryRepo)
  end

  def can_be_used_for_tps?
    is_binary_repo? && has_stable_systems_subscribed?
  end

  def is_parent?
    variant_id == variant.rhel_variant_id
  end

  # This is implemented here to support repositories that have
  # type set, but have not been persisted (see bug 1298490)
  def supports_package_mappings?
    self.type == 'CdnDockerRepo'
  end

  def get_parent
    return self if is_parent?
    variant.rhel_variant.cdn_repos.where("arch_id = ? and type = ?", arch, type).first
  end

  def short_release_type
    CdnRepo.short_release_type(self.release_type)
  end

  def short_type
    CdnRepo.short_content_type(self.type)
  end

  def self.short_release_type(type)
    short_name = strip_model_name(type)
    return (short_name == 'Eus') ? 'EUS' : short_name
  end

  def self.short_content_type(type)
    return type.gsub(/Cdn|Repo/, '')
  end

  # Returns one of:
  #  - source
  #  - debug
  #  - binary
  #  - docker
  def self.pdc_content_category
    result = self.short_content_type(self.name).downcase
    result == 'debuginfo' ? 'debug' : result
  end

  def self.display_name
    "CDN repository"
  end

  #
  # This lets you do `cdn_repo.update_attributes(:type=>'CdnBinaryRepo', ...)`
  # and it will change the STI type of the record. (Without this it will
  # not allow changing the type column with update_attributes).
  #
  def self.attributes_protected_by_default
    super - [self.inheritance_column]
  end

  def to_s
    name
  end

  private

  def self.strip_model_name(the_value)
    klass_name = CdnRepo.model_name
    return the_value.gsub(klass_name, '')
  end
  private_class_method :strip_model_name

  def valid_name_format
    if name.include?('.') && type != 'CdnDockerRepo'
      errors.add(:name, "contains illegal character '.'.")
    end
    if name.include? '/'
      errors.add(:name, "contains illegal character '/'.")
    end
  end

  def valid_type
    is_valid = CdnRepo.my_child?(type.constantize) rescue nil
    if !is_valid
      errors.add(:type, "is not valid.")
    end
  end

  def package_mappings_supported
    if !supports_package_mappings? && packages.any?
      errors.add(:cdn_repo, 'does not support package mappings')
    end
  end
end
