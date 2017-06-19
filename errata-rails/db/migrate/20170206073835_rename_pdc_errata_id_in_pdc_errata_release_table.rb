class RenamePdcErrataIdInPdcErrataReleaseTable < ActiveRecord::Migration

  def up
    remove_foreign_key :pdc_errata_releases, "pdc_errata_releases_ibfk_1"
    remove_index :pdc_errata_releases, :pdc_errata_id

    rename_column :pdc_errata_releases, :pdc_errata_id, :errata_id

    add_index :pdc_errata_releases, ["errata_id"]
    add_foreign_key :pdc_errata_releases, ["errata_id"], "errata_main", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "pdc_errata_releases_ibfk_1"
  end

  def down
    remove_foreign_key :pdc_errata_releases, "pdc_errata_releases_ibfk_1"
    remove_index :pdc_errata_releases, :errata_id

    rename_column :pdc_errata_releases, :errata_id, :pdc_errata_id

    add_index :pdc_errata_releases, ["pdc_errata_id"]
    add_foreign_key :pdc_errata_releases, ["pdc_errata_id"], "errata_main", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "pdc_errata_releases_ibfk_1"
  end

end
