class AddValidBugStatesToProduct < ActiveRecord::Migration
  def self.up
    add_column :errata_products, :valid_bug_states, :string, :default => 'MODIFIED,VERIFIED'
  end

  def self.down
    remove_column :errata_products, :valid_bug_states
  end
end
