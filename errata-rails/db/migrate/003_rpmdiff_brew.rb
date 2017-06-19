# update rpmdiff_runs set brew_build_id = errata_files.brew_build_id , brew_rpm_id = errata_files.brew_rpm_id from errata_files where errata_file_id = errata_files.id and errata_files.errata_id in (select id from errata_main where is_brew = 1) and errata_files.brew_rpm_id != -1;

class RpmdiffBrew < ActiveRecord::Migration
  def self.up
    add_column :rpmdiff_runs, :brew_build_id, :integer,
    :description => 'Build for rpmdiff run. Reference to brew_build(id)'

    add_column :rpmdiff_runs, :brew_rpm_id, :integer,
    :description => 'Brew SRPM for rpmdiff run. Reference to brew_rpms(id)'

    add_foreign_key "rpmdiff_runs", ["brew_build_id"], "brew_builds", ["id"]
    add_foreign_key "rpmdiff_runs", ["brew_rpm_id"], "brew_rpms", ["id"]
  end

  def self.down
    remove_column :rpmdiff_runs, :brew_build_id
    remove_column :rpmdiff_runs, :brew_rpm_id
  end
end
