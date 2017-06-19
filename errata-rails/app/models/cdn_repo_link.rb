class CdnRepoLink < ActiveRecord::Base
  include DistLink

  belongs_to :cdn_repo
  alias_attribute :dist, :cdn_repo

  belongs_to :variant

  has_one :product_version, :through => :variant

  validates_presence_of :variant, :cdn_repo
  validate :valid_product, :if => [:variant, :cdn_repo]

  def self.dist_type
    :cdn_repo
  end

  private
  def valid_product
    unless variant.product == cdn_repo.variant.product
      errors.add(:variant, "Variants do not match product: Link variant #{variant.name} is #{variant.product.name} versus repo variant #{cdn_repo.variant.name} product #{cdn_repo.variant.product.name}")
    end
  end
end
