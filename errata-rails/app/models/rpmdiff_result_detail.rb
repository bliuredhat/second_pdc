class RpmdiffResultDetail < ActiveRecord::Base
  self.table_name = 'rpmdiff_result_details'
  self.primary_key = 'result_detail_id'

  belongs_to :rpmdiff_score,
    :foreign_key => 'score'

  belongs_to :rpmdiff_result,
    :foreign_key => 'result_id'

  has_one :rpmdiff_autowaived_result_detail,
    :foreign_key => 'result_detail_id'

  # When result detail is waived, it should have one and only one matched rule
  has_one :matched_rule,
    :class_name => 'RpmdiffAutowaiveRule',
    :through => :rpmdiff_autowaived_result_detail,
    :source => :rpmdiff_autowaive_rule

  def similar_waiver_rules
    run = rpmdiff_result.rpmdiff_run
    RpmdiffAutowaiveRule.where(:score => score,
                               :test_id => rpmdiff_result.test_id,
                               :subpackage => subpackage,
                               :package_name => run.package_name)
  end

end
