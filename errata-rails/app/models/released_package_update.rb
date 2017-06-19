class ReleasedPackageUpdate < ActiveRecord::Base
  include Audited

  serialize :user_input, Hash

  belongs_to :who, :class_name => 'User'
  has_many :released_package_audits
  has_many :released_packages, :through => :released_package_audits
  has_many :pdc_released_packages, :through => :released_package_audits

  def add_released_packages(rps)
    current_rps = released_packages.pluck('distinct(released_packages.id)')
    rps.uniq.each do |rp|
      released_packages << rp unless current_rps.include?(rp.id)
    end
  end
end
