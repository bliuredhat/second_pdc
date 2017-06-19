class RemoveProductVersionFromChannels < ActiveRecord::Migration
  def up
    remove_column :channels, :product_version_id
  end

  def down
    add_column :channels, :product_version_id, :integer, :null => false
    Channel.joins(:variant).update_all('channels.product_version_id = errata_versions.product_version_id')
    add_foreign_key :channels, :product_version_id, :product_versions, :id, :name => 'channels_ibfk_3'
  end
end
