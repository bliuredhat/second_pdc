class FixErrataStatusDefault < ActiveRecord::Migration
  def self.up
    change_column :errata_main, :status, :string, :limit => 64, :default => "NEW_FILES", :null => false
  end

  def self.down
  end
end
