class MysqlMediumText < ActiveRecord::Migration
  def self.up
    change_column :rpmdiff_results, :log, :text, :limit => 64.kilobytes + 1
    change_column :comments, :text, :text, :limit => 64.kilobytes + 1
  end

  def self.down
    change_column :rpmdiff_results, :log, :text
    change_column :comments, :text, :text
  end
end
