class AddActualShipDate < ActiveRecord::Migration
  def self.up
    add_column :errata_main, :actual_ship_date, :datetime
  end

  def self.down
    remove_column :errata_main, :actual_ship_date
  end
end
