class AddPackagesToCdnRepos < ActiveRecord::Migration

  def change
    create_table :cdn_repo_packages, :force => true do |t|
      t.integer "cdn_repo_id", :null => false
      t.integer "package_id", :null => false
      t.integer :who_id, :null => false
      t.timestamps
      t.index ["cdn_repo_id"], :name => "cdn_repo_id"
      t.index ["package_id"], :name => "package_id"
      t.index ["who_id"], :name => "who_id"
      t.index [:cdn_repo_id, :package_id], :unique => true
      t.foreign_key ["cdn_repo_id"], "cdn_repos", ["id"], :on_update => :restrict, :on_delete => :restrict
      t.foreign_key ["package_id"], "packages", ["id"], :on_update => :restrict, :on_delete => :restrict
      t.foreign_key ["who_id"], "users", ["id"]
    end
  end

end
