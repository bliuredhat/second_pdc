class ChangeTpsStartedDateToAllowNull < ActiveRecord::Migration
  def up
    change_column :tpsjobs, :started, :datetime, :null => true, :description => 'Timestamp job started'
  end

  def down
    change_column :tpsjobs, :started, :datetime, :null => false, :description => 'Timestamp job started'
  end
end
