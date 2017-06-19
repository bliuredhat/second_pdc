class AddUrlNames < ActiveRecord::Migration
  def self.up
    add_column :releases, :url_name, :string
    Release.find(:all).each { |r| r.save(:validate => false) }
  end

  def self.down
    remove_column :releases, :url_name
  end
end
