class ResponsibilityShortName < ActiveRecord::Migration
  def self.up
    add_column :errata_responsibilities, :url_name, :string
  end

  def self.down
    remove_column :errata_responsibilities, :url_name
  end
  
end

