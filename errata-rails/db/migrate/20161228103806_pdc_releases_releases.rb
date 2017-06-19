class PdcReleasesReleases < ActiveRecord::Migration
  def up
    create_table :pdc_releases_releases, :id => false do |t|
      t.references :pdc_release
      t.references :release
    end
    add_index :pdc_releases_releases, [:release_id, :pdc_release_id]
  end

  def down
    drop_table :pdc_releases_releases
  end
end
