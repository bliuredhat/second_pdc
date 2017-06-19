class AlterCdnPathsToRepos < ActiveRecord::Migration
  def self.up
    rename_column :channels, :cdn_path, :cdn_binary_repo
    add_column :channels, :cdn_source_repo, :string
    add_column :channels, :cdn_debuginfo_repo, :string
  end

  def self.down
    remove_column :channels, :cdn_source_repo
    remove_column :channels, :cdn_debuginfo_repo
    rename_column :channels, :cdn_binary_repo, :cdn_path
  end
end
