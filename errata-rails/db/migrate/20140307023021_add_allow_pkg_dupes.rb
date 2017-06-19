class AddAllowPkgDupes < ActiveRecord::Migration
  def change
    add_column :releases, :allow_pkg_dupes, :boolean, :null => false, :default => false, :description => 'Whether multiple advisories covering the same package are allowed in this release'
  end
end
