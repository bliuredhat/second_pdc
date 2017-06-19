class AddResultDetailIdToRpmdiffAutowaiveRules < ActiveRecord::Migration
  def change
    add_column :rpmdiff_autowaive_rule, :created_from_rpmdiff_result_detail_id, :integer, :null => true
    add_foreign_key 'rpmdiff_autowaive_rule', 'created_from_rpmdiff_result_detail_id', 'rpmdiff_result_details', 'result_detail_id'
  end
end
