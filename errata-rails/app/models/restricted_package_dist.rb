class RestrictedPackageDist < ActiveRecord::Base
  belongs_to :package_restriction
  belongs_to :push_target
  belongs_to :variant_push_target

  validate :allowed_push_targets

  def allowed_push_targets
    variant = package_restriction.variant
    self.variant_push_target = VariantPushTarget.find_by_variant_id_and_push_target_id(variant.id, push_target.id)
    if !self.variant_push_target
      errors.add(:push_target, "Variant '#{variant.name}' does not allow #{push_target.name}. Only allows #{variant.push_targets.map(&:name).join(', ')}.")
    end
  end
end
