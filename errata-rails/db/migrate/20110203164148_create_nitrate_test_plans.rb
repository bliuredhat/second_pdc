class CreateNitrateTestPlans < ActiveRecord::Migration
  def self.up
    create_table :nitrate_test_plans do |t|
      t.integer :errata_id, :null => false
      t.integer :who, :null => false
      t.timestamps
    end
    add_foreign_key "nitrate_test_plans", ["errata_id"], "errata_main", ["id"]
    add_foreign_key "nitrate_test_plans", ["who"], "users", ["id"]
  end

  def self.down
    drop_table :nitrate_test_plans
  end
end
