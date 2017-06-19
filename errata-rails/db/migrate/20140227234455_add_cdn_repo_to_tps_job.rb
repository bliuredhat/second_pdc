class AddCdnRepoToTpsJob < ActiveRecord::Migration
  def change
    add_column :tpsjobs, :cdn_repo_id, :integer
  end
end
