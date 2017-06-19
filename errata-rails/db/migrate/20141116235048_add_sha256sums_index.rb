class AddSha256sumsIndex < ActiveRecord::Migration
  def change
    add_index :sha256sums, [:value], :name => 'sha256sums_value_idx'
  end
end
