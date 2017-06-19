class CommentsTextSizeIncrease < ActiveRecord::Migration
  def self.up
    # For MySQL, default max length for TEXT columns is 65535
    change_column :comments, :text, :text
  end

  def self.down
    change_column :comments, :text, :string, :limit => 4000
  end
end
