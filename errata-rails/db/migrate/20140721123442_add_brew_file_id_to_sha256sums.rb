class AddBrewFileIdToSha256sums < ActiveRecord::Migration
  def up
    remove_foreign_key :sha256sums, 'sha256sums_ibfk_2'
    rename_column :sha256sums, :brew_rpm_id, :brew_file_id
    add_foreign_key :sha256sums, :brew_file_id, :brew_files, :id, :on_update => :restrict, :on_delete => :restrict, :name => 'sha256sums_brew_file_fk'
  end

  def down
    remove_foreign_key :sha256sums, 'sha256sums_brew_file_fk'
    rename_column :sha256sums, :brew_file_id, :brew_rpm_id
    add_foreign_key :sha256sums, :brew_rpm_id, :brew_files, :id, :on_update => :restrict, :on_delete => :restrict, :name => 'sha256sums_ibfk_2'
  end
end
