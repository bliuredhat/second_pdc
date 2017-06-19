class ErrataDeps < ActiveRecord::Migration
  def self.up
    create_table :advisory_dependencies,
    :description => 'Maps blocking and dependent advisories.', :id => false do |t|
      t.integer :blocking_errata_id, :null => false
      t.integer :dependent_errata_id, :null => false
    end
    add_foreign_key 'advisory_dependencies', ['blocking_errata_id'], 'errata_main', ['id']
    add_foreign_key 'advisory_dependencies', ['dependent_errata_id'], 'errata_main', ['id']
  end

  def self.down
    drop_table :advisory_dependencies
  end
end
