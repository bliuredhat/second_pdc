class TpsVariant < ActiveRecord::Base
  has_many :tps_streams, :dependent => :destroy
  validates_uniqueness_of :name
end
