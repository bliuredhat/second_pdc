class CreateCdnRepos < ActiveRecord::Migration
  def self.up
    create_table :cdn_repos do |t|
      t.string :type, :null => false
      t.string :name, :null => false
      t.integer :variant_id, :null => false
      t.integer :arch_id, :null => false
      t.timestamps
    end
    add_index :cdn_repos, :name, :unique => true
    add_foreign_key 'cdn_repos', 'arch_id', 'errata_arches', 'id'
    add_foreign_key 'cdn_repos', 'variant_id', 'errata_versions', 'id'

    create_table :cdn_repo_links do |t|
      t.integer :cdn_repo_id, :null => false
      t.integer :product_version_id, :null => false
      t.integer :variant_id, :null => false
      t.timestamps
    end

    add_foreign_key 'cdn_repo_links', 'variant_id', 'errata_versions', 'id'
    add_foreign_key 'cdn_repo_links', 'product_version_id', 'product_versions', 'id'
    add_foreign_key 'cdn_repo_links', 'cdn_repo_id', 'cdn_repos', 'id'


  end

  def self.down
    drop_table :cdn_repo_links
    drop_table :cdn_repos
  end
end
