class CreatedAndApprovedForRpmdiffAutowaiveRule < ActiveRecord::Migration
  def change
    add_column :rpmdiff_autowaive_rule, :created_by, :integer, :null => true, :references => :users, :indexed => true
    add_column :rpmdiff_autowaive_rule, :approved_by, :integer, :null => true, :references => :users, :indexed => true

    add_column :rpmdiff_autowaive_rule, :created_at, :datetime, :null => true
    add_column :rpmdiff_autowaive_rule, :approved_at, :datetime, :null => true
  end
end
