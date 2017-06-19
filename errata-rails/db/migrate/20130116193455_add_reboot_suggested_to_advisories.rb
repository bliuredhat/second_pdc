# Adds optional reboot_suggested flag to advisories
# see https://bugzilla.redhat.com/show_bug.cgi?id=869677
class AddRebootSuggestedToAdvisories < ActiveRecord::Migration
  def self.up
    add_column :errata_main, :reboot_suggested, :boolean, :null => false, :default => false
  end

  def self.down
    remove_column :errata_main, :reboot_suggested
  end
end
