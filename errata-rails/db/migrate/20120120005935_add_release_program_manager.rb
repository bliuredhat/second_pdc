class AddReleaseProgramManager < ActiveRecord::Migration
  def self.up
    add_column :releases, :program_manager_id, :integer
    add_foreign_key :releases, :program_manager_id, :users, :id
  end

  def self.down
    remove_column :releases, :program_manager_id
  end
end
