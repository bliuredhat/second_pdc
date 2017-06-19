class AddPdcErrataReleaseBuildToRpmdiff < ActiveRecord::Migration
  def change
    add_column :rpmdiff_runs, :pdc_errata_release_build_id, :integer
    add_foreign_key "rpmdiff_runs", ["pdc_errata_release_build_id"], "pdc_errata_release_builds", ["id"]
  end
end
