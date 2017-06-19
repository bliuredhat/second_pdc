class AddShippedFlagToMappings < ActiveRecord::Migration
  def self.up
    add_column :errata_brew_mappings, :shipped, :integer, :null => false, :default => 0
    ErrataBrewMapping.update_all('shipped = 1',
                                  "current = 1 and errata_id in (select id from errata_main where is_brew = 1 and status = 'SHIPPED_LIVE')")
    
    add_column :brew_builds, :shipped, :integer, :null => false, :default => 0
    BrewBuild.update_all('shipped = 1',
                         "id in (select brew_build_id from released_packages where current = 1)")
  end

  def self.down
    drop_column :errata_brew_mappings, :shipped
    drop_column :brew_builds, :shipped
  end
end
