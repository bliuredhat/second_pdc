class Cve < ActiveRecord::Base
  belongs_to  :bug
  has_many :errata_cve_map
  has_many :errata, :through => :errata_cve_map
end
