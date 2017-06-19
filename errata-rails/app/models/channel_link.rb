class ChannelLink < ActiveRecord::Base
  include DistLink

  belongs_to :variant
  belongs_to :channel
  alias_attribute :dist, :channel

  has_one :product_version, :through => :variant

  validates_presence_of :variant, :channel
  validate :valid_product

  def self.dist_type
    :channel
  end

  private
  def valid_product
    unless self.product_version.product == channel.product_version.product
      errors.add(:channel, "Products do not match. #{self.product_version.name} is #{self.product_version.product.name}, " +
                 "whereas channel #{channel.name} belongs to #{channel.product_version.name} => #{channel.product_version.product.name}")
    end
  end
end
