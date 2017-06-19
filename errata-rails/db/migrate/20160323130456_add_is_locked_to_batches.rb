class AddIsLockedToBatches < ActiveRecord::Migration
  def change
    add_column :batches, :is_locked, :boolean, :default => false, :null => false
  end
end
