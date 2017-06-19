class VariantPushTarget < ActiveRecord::Base
  include Audited
  belongs_to :variant
  belongs_to :push_target
  belongs_to :active_push_target
  belongs_to :who, :class_name => 'User'

  validate :allowed_push_targets

  has_many :restricted_package_dists, :dependent => :destroy
  def allowed_push_targets
    product_version = variant.product_version
    allowable_push_targets = product_version.push_targets.allowable_by_variant.to_a
    self.active_push_target = product_version.active_push_targets.find_by_push_target_id(push_target.id)
    if !allowable_push_targets.include?(push_target) || !self.active_push_target
      error_message =
        "Variant #{variant.name} does not allow #{push_target.name}. Only allows"\
        " #{allowable_push_targets.map(&:name).join(', ')}"

      errors.add(:push_target, error_message)
    end
  end
end
