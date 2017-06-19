class AddFlagsToPdcErrataReleaseBuild < ActiveRecord::Migration
  def change
    add_column :pdc_errata_release_builds, :flags, :string, :null => false, :default => Set.new.to_yaml
  end
end
