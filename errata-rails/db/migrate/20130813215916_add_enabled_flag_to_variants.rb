class AddEnabledFlagToVariants < ActiveRecord::Migration
  def self.up
    add_column :errata_versions, :enabled, :boolean, :null => false, :default => true
  end

  def self.down
    remove_column :errata_versions, :enabled
  end
end
