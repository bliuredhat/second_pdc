class RemoveCdnRepoFieldsFromChannel < ActiveRecord::Migration
  def up
    remove_column :channels, :cdn_binary_repo
    remove_column :channels, :cdn_source_repo
    remove_column :channels, :cdn_debuginfo_repo
  end

  def down
    add_column :channels, :cdn_binary_repo, :string
    add_column :channels, :cdn_source_repo, :string
    add_column :channels, :cdn_debuginfo_repo, :string
  end
end
