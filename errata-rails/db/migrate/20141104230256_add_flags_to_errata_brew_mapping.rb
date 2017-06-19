class AddFlagsToErrataBrewMapping < ActiveRecord::Migration
  def change
    add_column :errata_brew_mappings, :flags, :string, :null => false, :default => Set.new.to_yaml
  end
end
