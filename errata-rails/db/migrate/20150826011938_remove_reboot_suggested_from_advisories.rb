# Removes optional reboot_suggested flag from advisories
# see https://bugzilla.redhat.com/show_bug.cgi?id=1113061
class RemoveRebootSuggestedFromAdvisories < ActiveRecord::Migration
  def up
    remove_column :errata_main, :reboot_suggested
  end

  def down
    add_column :errata_main, :reboot_suggested, :boolean, :null => false, :default => false
  end
end
