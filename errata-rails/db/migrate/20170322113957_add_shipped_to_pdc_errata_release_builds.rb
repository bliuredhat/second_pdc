class AddShippedToPdcErrataReleaseBuilds < ActiveRecord::Migration
  def change
    add_column :pdc_errata_release_builds, :shipped, :boolean, :default => 0, :null => false
  end
end
