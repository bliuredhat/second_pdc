class ChangeRpmdiffWaiverPerson < ActiveRecord::Migration
  def self.up
    add_column :rpmdiff_waivers, :user_id, :integer
    RpmdiffWaiver.update_all('user_id = person')
    change_column :rpmdiff_waivers, :user_id, :integer, :null => false
    add_foreign_key "rpmdiff_waivers", ['user_id'], "users", ["id"]
    remove_foreign_key 'rpmdiff_waivers', 'person_fk'
  end

  def self.down
  end
end
