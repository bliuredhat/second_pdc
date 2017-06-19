class AddReleasedAtToBatches < ActiveRecord::Migration
  def change
    add_column :batches, :released_at, :datetime, :null => true
  end
end
