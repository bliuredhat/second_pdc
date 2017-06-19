class ContainerContents < ActiveRecord::Migration

  def change
    create_table :container_contents, :force => true do |t|
      t.integer :brew_build_id, :null => false
      # Need to store msec and mysql < 5.6 datetime doesn't
      t.string :mxor_updated_at
      t.index ["brew_build_id"], :name => "brew_build_id"
      t.foreign_key ["brew_build_id"], "brew_builds", ["id"]
    end

    create_table :container_repos, :force => true do |t|
      t.integer :container_content_id, :null => false
      t.string :name, :null => false
      t.integer :cdn_repo_id
      t.string :tags, :limit => 4000
      t.index ["container_content_id"], :name => "container_content_id"
      t.index ["name"], :name => "name"
      t.foreign_key ["container_content_id"], "container_contents", ["id"]
      t.foreign_key ["cdn_repo_id"], "cdn_repos", ["id"]
    end

    create_table :container_repo_errata, :force => true do |t|
      t.integer :container_repo_id, :null => false
      t.integer :errata_id, :null => false
      t.index ["container_repo_id"], :name => "container_repo_id"
      t.index ["errata_id"], :name => "errata_id"
      t.foreign_key ["container_repo_id"], "container_repos", ["id"]
      t.foreign_key ["errata_id"], "errata_main", ["id"]
    end
  end

end
