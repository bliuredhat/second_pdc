class RpmdiffWaiverPermission < ActiveRecord::Migration
  def self.up
    add_column :rpmdiff_results, :can_approve_waiver, :string 
  end

  def self.down
    remove_column :rpmdiff_results, :can_approve_waiver
  end
end
