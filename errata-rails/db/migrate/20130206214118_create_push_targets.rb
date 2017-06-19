class CreatePushTargets < ActiveRecord::Migration
  def self.up
    rename_column :product_versions, :push_types, :unused_push_types
    create_table :push_targets do |t|
      t.string :name, :null => false, :unique => true
      t.string :description, :null => false
      t.string :push_type, :null => false
      # Defines a Red Hat internal only push target
      t.integer :is_internal, :boolean, :null => false, :default => false
      t.timestamps
    end

    create_table :allowable_push_targets do |t|
      t.integer :product_id, :null => false
      t.integer :push_target_id, :null => false
      t.integer :who_id, :null => false
      t.timestamps
    end

    create_table :active_push_targets do |t|
      t.integer :product_version_id, :null => false
      t.integer :push_target_id, :null => false
      t.integer :who_id, :null => false
      t.timestamps
    end
    add_column :push_jobs, :push_target_id, :integer, :null => false
  end

  def self.down
    rename_column :product_versions, :unused_push_types, :push_types
    remove_column :push_jobs, :push_target_id
    drop_table :active_push_targets
    drop_table :allowable_push_targets
    drop_table :push_targets
  end
end
