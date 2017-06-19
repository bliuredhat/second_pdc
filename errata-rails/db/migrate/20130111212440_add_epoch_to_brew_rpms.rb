class AddEpochToBrewRpms < ActiveRecord::Migration
  def self.up
    add_column :brew_rpms, :epoch, :integer, :null => false, :default => 0
    BrewBuild.where("epoch != '' and epoch != '0'").each do |b|
      BrewRpm.where(:brew_build_id => b).update_all(:epoch => b.epoch.to_i)
    end
  end

  def self.down
    remove_column :brew_rpms, :epoch
  end
end
