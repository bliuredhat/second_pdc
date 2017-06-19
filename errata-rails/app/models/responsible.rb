module Responsible
  def self.included(base)
    base.class_eval do 
      has_many :packages, :order => 'name'
      has_many :errata,
      :class_name => 'Errata',
      :conditions => "errata_main.id in (select id from errata_main where is_valid = 1 and status not in ('SHIPPED_LIVE', 'DROPPED_NO_SHIP'))"
    end
  end
end
