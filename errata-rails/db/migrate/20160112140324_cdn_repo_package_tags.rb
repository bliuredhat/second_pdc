class CdnRepoPackageTags < ActiveRecord::Migration

  def change
    create_table :cdn_repo_package_tags, :force => true do |t|
      t.integer :cdn_repo_package_id, :null => false
      t.string :tag_template, :null => false
      t.integer :who_id, :null => false
      t.timestamps
      t.index [:cdn_repo_package_id, :tag_template], :name => 'cdn_repo_package_tags_unique_1', :unique => true
      t.index ["who_id"], :name => "who_id"
      t.foreign_key ["cdn_repo_package_id"], "cdn_repo_packages", ["id"], :on_delete => :cascade
      t.foreign_key ["who_id"], "users", ["id"]
    end
  end

end
