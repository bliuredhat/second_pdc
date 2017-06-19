class MultipleProductVersionForRelease < ActiveRecord::Migration
  def self.up
    create_table :product_versions_releases, :id => false do |t|
      t.integer :release_id, :null => false
      t.integer :product_version_id, :null => false
    end
    add_foreign_key 'product_versions_releases', 'release_id', 'releases', 'id'
    add_foreign_key 'product_versions_releases', 'product_version_id', 'product_versions', 'id'
    add_index "product_versions_releases", ['release_id', 'product_version_id'], :name => 'product_versions_releases_idx', :unique => true

    list = Release.connection.select_rows("select id,product_version_id from releases where product_version_id is not null")
    list.each do |l|
      r_id = l[0].to_i
      pv_id = l[1].to_i
      Release.connection.execute("insert into product_versions_releases(release_id, product_version_id) values (#{r_id}, #{pv_id})")
    end
  end
  
  def self.down
    drop_table :product_versions_releases
  end
end



# list = Release.connection.select_rows("select id,product_version_id from releases where product_version_id is not null")
# count = 0
# hsh = {}
# list.each do |l|
#   key = "join_#{count}"
#   hsh[key] = {:release_id => l[0],
#     :product_version_id => l[1]}
#   count += 1
# end
