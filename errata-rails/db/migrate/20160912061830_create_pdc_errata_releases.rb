class CreatePdcErrataReleases < ActiveRecord::Migration

  def change
    create_table :pdc_errata_releases do |t|
      t.integer :pdc_errata_id, :references => :errata_main
      t.integer :pdc_release_id, :references => :pdc_resources

      t.timestamps
    end
  end

end
