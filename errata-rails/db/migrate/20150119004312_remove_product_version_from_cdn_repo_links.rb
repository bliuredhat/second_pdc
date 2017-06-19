class RemoveProductVersionFromCdnRepoLinks < ActiveRecord::Migration
  def up
    # cannot delete_all directly because https://github.com/rails/rails/issues/919
    bad_links = CdnRepoLink.joins(:variant).select('cdn_repo_links.id').where('cdn_repo_links.product_version_id != errata_versions.product_version_id').to_a
    CdnRepoLink.where(:id => bad_links).delete_all
    remove_column :cdn_repo_links, :product_version_id
  end

  def down
    add_column :cdn_repo_links, :product_version_id, :integer, :null => false
    CdnRepoLink.joins(:variant).update_all('cdn_repo_links.product_version_id = errata_versions.product_version_id')
    add_foreign_key :cdn_repo_links, :product_version_id, :product_versions, :id, :name => 'cdn_repo_links_ibfk_2'
  end
end
