class AddMd5sumsIndex < ActiveRecord::Migration
  def change
    add_index :md5sums, [:value], :name => 'md5sums_value_idx'
  end
end
