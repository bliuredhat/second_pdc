class ActivePushTarget < ActiveRecord::Base
  include Audited
  belongs_to :product_version
  belongs_to :push_target
  belongs_to :who,
  :class_name => 'User'

  has_many :variant_push_targets, :dependent => :destroy

  validate do
    product = product_version.product
    unless product.push_targets.include? push_target
      errors.add(:push_target, "Product #{product.name} does not allow push target #{push_target.name}. Only allows #{product.push_targets.map(&:name).join(', ')}")
    end
  end
end
