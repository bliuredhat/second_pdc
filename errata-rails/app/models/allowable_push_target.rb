class AllowablePushTarget < ActiveRecord::Base
  include Audited
  belongs_to :product
  belongs_to :push_target
  belongs_to :who,
  :class_name => 'User'
  validates_uniqueness_of :product_id, :scope => :push_target_id
  validate :internal_product
  validate(:on => :create) do
    existing_target_for_push_type = product.push_targets.select {|t| t.push_type == push_target.push_type}.first
    if existing_target_for_push_type
      errors.add(:push_target, "Product #{product.name} already has a target with push type #{push_target.push_type}: #{existing_target_for_push_type}")
    end
  end

  protected
  def internal_product
    if product.is_internal? && !push_target.is_internal?
      errors.add(:product, "Product #{product.name} is an internal only product, cannot use external push target #{push_target.name}")
    end
  end
end
