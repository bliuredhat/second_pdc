class AddBugsAliasIndex < ActiveRecord::Migration
  def up
    add_index :bugs, [:alias], :name => 'bugs_alias_idx'
  end

  def down
    remove_index :bugs, :name => 'bugs_alias_idx'
  end
end
