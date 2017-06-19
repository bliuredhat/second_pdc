class MultiProductChannelMap < ActiveRecord::Base
  include MultiProductMap
  belongs_to :origin_channel, :class_name => 'Channel'
  belongs_to :destination_channel, :class_name => 'Channel'

  alias_method :destination_dist, :destination_channel

  has_many :multi_product_channel_map_subscriptions, :dependent => :destroy

  validates_presence_of :origin_channel,
                        :destination_channel

  validate :destination_is_allowed

  def self.mappings_for_package(origin_channels, pkg)
    where(:origin_channel_id => origin_channels, :package_id => pkg)
  end

  def self.mapping_type
    :channel
  end

  protected

  def destination_is_allowed
    return if any_required_fields_nil?
    dest_product = destination_product_version.product
    if dest_product.is_rhel? || dest_product.is_extras?
      errors.add(:destination_product_version, "RHEL or RHEL Optional is _not_ allowed as a destination")
    end
  end

end
