class FixBrewNvrIdx < ActiveRecord::Migration
  def self.up
    remove_index :brew_builds, :name => :brew_build_nvr
    add_index :brew_builds, :nvr, :unique => true
  end

  def self.down
  end
end
