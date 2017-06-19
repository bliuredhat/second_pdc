# == Schema Information
#
# Table name: errata_versions
#
#  id                 :integer       not null, primary key
#  product_id         :integer       not null
#  name               :string(255)   not null
#  description        :string(2000)
#  rhn_channel_tmpl   :string(2000)
#  product_version_id :integer       not null
#  rhel_variant_id    :integer
#  rhel_release_id    :integer       not null
#  cpe                :string
#

class Variant < ActiveRecord::Base
  include FindByIdOrName
  include PushTargetsWere
  include CanonicalNames

  self.table_name = "errata_versions"
  validates_uniqueness_of :name
  belongs_to :product
  belongs_to :product_version

  belongs_to :rhel_variant,
  :class_name => "Variant",
  :foreign_key => "rhel_variant_id"

  belongs_to :rhel_release
  has_many :channels
  has_many :channel_links
  has_many :cdn_repos
  has_many :cdn_repo_links

  has_many :variant_push_targets, :dependent => :destroy
  has_many :push_targets, :through => :variant_push_targets, :dependent => :destroy

  has_many :package_restrictions, :dependent => :destroy
  has_many :restricted_packages, :through => :package_restrictions, :source => :package, :dependent => :destroy

  validate :rhel_release_valid, :rhel_variant_valid, :tps_stream_valid
  validates :name, :presence => true
  validate :has_no_active_errata, :on => :update, :if => :push_target_changed?
  scope :rhel_variants, where('id = rhel_variant_id')
  scope :with_cpe, where("cpe is not null and cpe != ''")

  scope :attached_to_cdn_repo, lambda { |repo| joins(:cdn_repo_links).where(:cdn_repo_links => {:cdn_repo_id => repo}) }

  before_validation(:on => :create) do
    self.rhel_release ||= self.product_version.rhel_release
    self.product ||= self.product_version.product
  end

  def release_version
    product_version
  end

  def verbose_name
    description
  end

  def short_name
    name
  end

  after_create do
    unless self.rhel_variant
      update_attribute(:rhel_variant, self)
    end
  end

  def self.live_variant_ids
    errata_ids = Errata.shipped_live.where(:closed => true,
                                           :is_brew => true).joins(:content).merge(Content.with_cve).pluck(:id)
    ErrataFile.current.where(:errata_id => errata_ids).pluck(:version_id).uniq
  end

  def self.live
    where(:id => live_variant_ids).order(:name)
  end

  def self.live_variants_with_cpe
    Variant.live.with_cpe
  end

  def has_cpe?
    self.cpe.present?
  end

  def is_rhel_variant?
    return self.product.is_rhel? && self.rhel_variant_id == self.id
  end

  # See a/m/oval_test
  def cpe_for_oval
    cpe_first_n_fields(5)
  end

  # Returns true if this variant is part of any advisory that has shipped live
  def has_been_shipped_live?
    ErrataBrewMapping.current.where(:product_version_id => product_version).joins(:errata).merge(Errata.shipped_live).any?
  end

  def public_cpe_data_changed?
    return false unless cpe_changed?
    has_been_shipped_live?
  end

  def determine_tps_stream
    variant = is_parent? ? self : rhel_variant
    # If tps stream not set, then try to workout a TPS stream
    return TpsStream.get_by_errata_variant(variant) if variant.tps_stream.blank?
    # Return nil if 'None' is set to keep some old variants like 2.1AS, 2.1AW happy
    return [nil, HashList.new] if variant.tps_stream == 'None'
    # Otherwise, check whether it is valid or not
    TpsStream.get_by_full_name(variant.tps_stream)
  end

  def get_tps_stream
    determine_tps_stream[0].try(:full_name)
  end

  def get_tps_stream_errors
    determine_tps_stream[1]
  end

  def is_parent?
    self.id == self.rhel_variant_id
  end

  def supported_push_types
    push_targets.collect {|t| t.push_type.to_sym}.uniq
  end

  def active_errata
    # Active advisories that are mapping to the variant may be affected by the push targets
    # change, such as tps jobs, push file list etc. Better to disallow user to add/update the
    # variant push targets when there is a active advisory (exclude NEW_FILES) depending on
    # the variant.
    unless @affected
      @affected = []
      ErrataFile.
        select('distinct errata_id').
        includes(:errata).
        current.
        for_variant(self).
      each do |et_file|
        errata = et_file.errata
        if errata.is_active? && errata.filelist_locked?
          @affected << errata
        end
      end
    end

    return @affected
  end

  private

  # (This returns "" if cpe is nil or empty).
  def cpe_first_n_fields(n)
    cpe_split_fields[0...n].join(':')
  end

  # CPEs use a colon delimiter, eg "cpe:/a:redhat:openshift:1::el6".
  # (This returns [] if cpe is nil or empty).
  def cpe_split_fields
    (cpe||'').strip.split(':')
  end

  def tps_stream_valid
    if self.is_parent?
      # Only raise error if it is a fatal error
      self.get_tps_stream_errors[:fatal].each do |error|
        errors.add(:tps_stream, error.message)
      end
    elsif !self.is_parent? && self.tps_stream.present?
      errors.add(:tps_stream, 'is not allow to set for sub variant.')
    end
  end

  def rhel_release_valid
    unless rhel_release == product_version.rhel_release
      errors.add(:rhel_release,
                 "Product Version is #{product_version.rhel_release.name}, and variant is #{rhel_release.try(:name)}")
    end
  end

  def rhel_variant_valid
    if self.rhel_variant.nil?
      errors.add(:rhel_variant, 'cannot be nil') unless new_record?
      return
    end

    unless self.name.start_with? self.rhel_variant.name.split('-').first
      errors.add(:rhel_variant, "#{self.name} does not start with #{self.rhel_variant.name}")
    end
    if self.product.is_rhel?
      unless self.rhel_variant.product_version == self.product_version
        errors.add(:rhel_variant, ["RHEL product version mismatch for rhel variant: ",
                                   "Variant #{self.name} Product version #{self.product_version.name}, ",
                                   "RHEL Variant #{self.rhel_variant.name} Product version #{self.rhel_variant.product_version.name}"].join)
      end
    end
  end

  def has_no_active_errata
    unless self.active_errata.empty?
      # better error message?
      error_message =
        "Update push targets for variant that has active advisories with locked filelist"\
        " is not allowed. To amend the push targets, please make sure all depending"\
        " active advisories are either inactive or in unlocked state."

      errors.add(:base, error_message)
    end
  end

  def push_target_changed?
    return true if self.push_targets_were
    return false
  end
end
