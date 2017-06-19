class AddRpmdiffAutowaiveRule < ActiveRecord::Migration
  def up
    create_table :rpmdiff_autowaive_rule, :primary_key => 'autowaive_rule_id' do |t|
      t.boolean :active
      t.string :package_name, :null => false, :limit => 256
      t.string :package_version, :limit => 256
      t.integer :test_id, :null => false
      t.string :subpackage, :limit => 256
      t.string :string_expression, :null => false, :limit => 1000
      t.string :reason, :limit => 1000
      t.foreign_key ["test_id"], "rpmdiff_tests", ["test_id"], :on_update => :restrict, :on_delete => :cascade
    end
  end

  def down
    drop_table :rpmdiff_autowaive_rule
  end
end
