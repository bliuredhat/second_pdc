class ErrataCveMap < ActiveRecord::Base

  belongs_to :errata,
  :class_name => "Errata",
  :foreign_key => 'errata_id'
  belongs_to :cve

  
end
