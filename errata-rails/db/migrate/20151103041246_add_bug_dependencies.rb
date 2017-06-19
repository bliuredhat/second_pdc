class AddBugDependencies < ActiveRecord::Migration
  def up
    create_table(:bug_dependencies) do |t|
      t.integer :bug_id,        :null => false
      t.integer :blocks_bug_id, :null => false
      t.datetime :created_at
    end
    add_index(:bug_dependencies, [:bug_id, :blocks_bug_id], :unique => true)
    add_index(:bug_dependencies, :blocks_bug_id)

    # Note that the columns in this table are intentionally not declared as
    # foreign keys. This is to permit storing of dependency information for bugs
    # which are unavailable, e.g. bugs which are restricted such that ET can't
    # see them, or bugs which haven't yet been fetched.
  end

  def down
    drop_table(:bug_dependencies)
  end
end
