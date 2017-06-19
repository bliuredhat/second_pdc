class AddTextOnlyCdnRepoList < ActiveRecord::Migration
  def change
    add_column :text_only_channel_lists, :cdn_repo_list, :text, :null => false, :default => ''
  end
end
