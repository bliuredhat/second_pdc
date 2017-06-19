class ReleasedPackageAudit < ActiveRecord::Base
  belongs_to :released_package
  belongs_to :released_package_update
  belongs_to :pdc_released_package

  validate :released_package_valid

  def released_package_valid
    unless pdc_released_package || released_package
      errors.add(:released_package_and_pdc_released_package, "can't be both null")
    end

    if pdc_released_package && released_package
      errors.add(:released_package_and_pdc_released_package, "can't both be set")
    end
  end

end
