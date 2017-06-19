class Channel < ActiveRecord::Base
  include FindByIdOrName
  include NamedAttributes
  include ModelChild
  include CanonicalNames
  include ModelDist
  include TpsTests

  TYPES = %w[
    BetaChannel
    EusChannel
    FastTrackChannel
    LongLifeChannel
    PrimaryChannel
  ]

  belongs_to :variant
  belongs_to :arch
  has_one :product_version, :through => :variant

  # :destroy so we don't have orphaned channel_links when a channel is removed.
  # Is that okay??
  has_many :channel_links, :dependent => :destroy
  alias_attribute :links, :channel_links
  alias_attribute :use_for_tps, :has_stable_systems_subscribed
  alias_attribute :release_type, :type

  has_many :tps_jobs, :dependent => :restrict

  has_many :multi_product_mapped_origin_channels,
           :class_name => 'MultiProductChannelMap',
           :foreign_key => :origin_channel_id,
           :dependent => :restrict
  has_many :multi_product_mapped_destination_channels,
           :class_name => 'MultiProductChannelMap',
           :foreign_key => :destination_channel_id,
           :dependent => :restrict

  validates_inclusion_of :type, :in => TYPES, :message => 'is not valid'
  validates_presence_of :name, :variant, :arch
  validates_uniqueness_of :name

  scope :with_stable_systems, where(:has_stable_systems_subscribed => true)
  after_create do
    ChannelLink.create(:channel => self,
                       :product_version => self.product_version,
                       :variant => self.variant)
  end

  named_attributes :arch, :variant

  def self.channel_types
    TYPES
  end

   def self.inherited(child)
     child.instance_eval do
       def model_name
         Channel.model_name
       end

       def display_name
         Channel.display_name
       end
     end
     super
   end

  #
  # This lets you do `channel.update_attributes(:type=>'EusChannel', ...)`
  # and it will change the STI type of the record. (Without this it will
  # not allow changing the type column with update_attributes).
  #
  def self.attributes_protected_by_default
    super - [self.inheritance_column]
  end

  def short_type
    return 'Channel' if type == 'Channel'
    type.gsub('Channel','').gsub(/^Eus/,'EUS')
  end

  def is_rhel_optional?
    self.name =~ /optional/ && self.product_version.product.is_rhel?
  end

  def is_layered_product?
    !(self.product_version.product.is_rhel? || self.product_version.product.is_extras?)
  end

  def can_be_used_for_tps?
    has_stable_systems_subscribed?
  end

  def is_parent?
    variant_id == variant.rhel_variant_id
  end

  def get_parent
    return self if is_parent?
    parent = variant.rhel_variant.channels.where('arch_id = ? and type = ?', arch, type).first
    return parent
  end

  def sub_channels
    product_version.channels.where(['arch_id = ? and variant_id = ? and type != ?', arch_id, variant_id,type])
  end

  def self.display_name
    "RHN channel"
  end

  def to_s
    name
  end
end
