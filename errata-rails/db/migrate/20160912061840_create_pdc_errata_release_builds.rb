class CreatePdcErrataReleaseBuilds < ActiveRecord::Migration

  def change
    create_table :pdc_errata_release_builds do |t|
      t.integer :pdc_errata_release_id, :references => :pdc_errata_releases
      t.integer :brew_build_id, :references => :brew_builds

      t.timestamps
    end
  end

end
