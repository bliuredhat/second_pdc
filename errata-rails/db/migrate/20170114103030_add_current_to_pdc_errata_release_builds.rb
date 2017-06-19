class AddCurrentToPdcErrataReleaseBuilds < ActiveRecord::Migration
  def change
    add_column :pdc_errata_release_builds, :current, :integer, :null => false, :default => 1
  end
end
