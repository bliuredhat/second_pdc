# This migration adds volume name to brew build details to add the possibility of
# attaching brew-stage builds to advisories in ET-stage
# See bug: 1316182
class AddVolumeNameToBrewBuild < ActiveRecord::Migration
  def change
    add_column :brew_builds,
               :volume_name,
               :string
  end
end
