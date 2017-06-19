class AddTpsStreamToErrataVersions < ActiveRecord::Migration
  def change
    add_column :errata_versions, :tps_stream, :string, :null => true, :description => 'Tell TPS which machine to run on'
  end
end
