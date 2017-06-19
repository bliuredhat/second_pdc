class AddRpmdiffAutowaivedResultDetails < ActiveRecord::Migration
  def up
    create_table :rpmdiff_autowaived_result_details,
      :description => 'Manage which result detail is waived by which rule automatically.' do |t|

      t.integer :result_detail_id, :null => false,
        :references => [:rpmdiff_result_details, :result_detail_id]
      t.integer :autowaive_rule_id, :null => false,
        :references => [:rpmdiff_autowaive_rule, :autowaive_rule_id]
      t.datetime :created_at, :null => false
    end

    add_index :rpmdiff_autowaived_result_details,
      [:result_detail_id, :autowaive_rule_id],
      :unique => true,
      :name => 'uniq_idx_autowaived_result_details'
  end

  def down
    drop_table :rpmdiff_autowaived_result_details
  end
end
