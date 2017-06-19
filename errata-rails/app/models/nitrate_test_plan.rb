class NitrateTestPlan < ActiveRecord::Base
  include Audited
  belongs_to :errata
  belongs_to :who,
  :class_name => "User"

end
