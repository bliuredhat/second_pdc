class AddNameIndexForBrewRpms < ActiveRecord::Migration
  def up
    add_index "brew_rpms", ["name"], :name => "brew_rpm_name"
  end

  def down
    remove_index "brew_rpms", :name => "brew_rpm_name"
  end
end
