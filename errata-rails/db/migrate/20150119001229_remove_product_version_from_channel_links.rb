class RemoveProductVersionFromChannelLinks < ActiveRecord::Migration
  def up
    # cannot delete_all directly because https://github.com/rails/rails/issues/919
    bad_links = ChannelLink.joins(:variant).select('channel_links.id').where('channel_links.product_version_id != errata_versions.product_version_id').to_a
    ChannelLink.where(:id => bad_links).delete_all
    remove_column :channel_links, :product_version_id
  end

  def down
    add_column :channel_links, :product_version_id, :integer, :null => false
    ChannelLink.joins(:variant).update_all('channel_links.product_version_id = errata_versions.product_version_id')
    add_foreign_key :channel_links, :product_version_id, :product_versions, :id, :name => 'channel_links_ibfk_2'
  end
end
