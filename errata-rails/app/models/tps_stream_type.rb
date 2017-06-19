class TpsStreamType < ActiveRecord::Base
  has_many :tps_streams, :dependent => :destroy
  validates_uniqueness_of :name

  def is_zstream?
    self.name =~ /^Z$/i
  end
end
