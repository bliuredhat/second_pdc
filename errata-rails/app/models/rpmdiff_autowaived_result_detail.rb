class RpmdiffAutowaivedResultDetail < ActiveRecord::Base
  belongs_to :rpmdiff_result_details, :foreign_key => 'result_detail_id'
  belongs_to :rpmdiff_autowaive_rule, :foreign_key => 'autowaive_rule_id'

end
