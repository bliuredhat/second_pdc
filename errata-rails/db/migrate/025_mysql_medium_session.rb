class MysqlMediumSession < ActiveRecord::Migration
  def self.up
    change_column :sessions, :data, :text, :limit => 64.kilobytes + 1
  end

  def self.down
    change_column :sessions, :data, :text
  end
end
