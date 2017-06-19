class ErrataColFix < ActiveRecord::Migration
  def self.up
    remove_column :errata_main, :class
    add_column :errata_main, :is_valid, :integer, :null => false, :default => 1
    Errata.update_all('is_valid = valid')
    remove_column :errata_main, :valid
  end

  def self.down
  end
end
