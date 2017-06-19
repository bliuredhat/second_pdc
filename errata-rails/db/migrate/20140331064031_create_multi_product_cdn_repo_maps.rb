class CreateMultiProductCdnRepoMaps < ActiveRecord::Migration
  def change
    create_table :multi_product_cdn_repo_maps, :foreign_keys => {:auto_create => false} do |t|
      t.integer :origin_cdn_repo_id, :null => false
      t.integer :origin_product_version_id, :null => false
      t.integer :destination_cdn_repo_id, :null => false
      t.integer :destination_product_version_id, :null => false
      t.integer :package_id, :null => false
      t.integer :user_id, :null => false
      t.timestamps
    end
  end
end
