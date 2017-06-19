class RpmdiffAutowaiveProductVersion < ActiveRecord::Base

  belongs_to :product_version
  belongs_to :rpmdiff_autowaive_rule

end
