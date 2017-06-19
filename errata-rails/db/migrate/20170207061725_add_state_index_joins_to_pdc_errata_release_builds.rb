class AddStateIndexJoinsToPdcErrataReleaseBuilds < ActiveRecord::Migration
  def change
    add_column :pdc_errata_release_builds, :removed_index_id, :integer, :references => :state_indices
    add_column :pdc_errata_release_builds, :added_index_id, :integer, :references => :state_indices
  end
end
