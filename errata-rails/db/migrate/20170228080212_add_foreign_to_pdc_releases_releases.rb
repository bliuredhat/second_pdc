class AddForeignToPdcReleasesReleases < ActiveRecord::Migration
  def up
    add_foreign_key :pdc_releases_releases, :pdc_release_id, :pdc_resources, :id, :name => :pdc_releases_releases_ibfk_1, :on_delete => :restrict
    add_foreign_key :pdc_releases_releases, :release_id, :releases, :id, :name => :pdc_releases_releases_ibfk_2, :on_delete => :restrict
  end

  def down
    remove_foreign_key :pdc_releases_releases, :pdc_releases_releases_ibfk_1
    remove_foreign_key :pdc_releases_releases, :pdc_releases_releases_ibfk_2
    # created in foreign key creation
    remove_index(:pdc_releases_releases, :name => :pdc_releases_releases_ibfk_1)
  end
end
