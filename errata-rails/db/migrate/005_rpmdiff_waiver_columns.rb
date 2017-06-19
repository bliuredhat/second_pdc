# update rpmdiff_runs set package_id = (select id from errata_packages where name = package_name);
# update rpmdiff_waivers set test_id = (select rpmdiff_results.test_id from rpmdiff_results where rpmdiff_waivers.result_id = rpmdiff_results.result_id);
#update rpmdiff_waivers set run_id = (select rpmdiff_results.run_id from rpmdiff_results where rpmdiff_waivers.result_id = rpmdiff_results.result_id);
# update rpmdiff_waivers set package_id = (select rpmdiff_runs.package_id from rpmdiff_runs where rpmdiff_waivers.run_id = rpmdiff_runs.run_id);
#    alter table rpmdiff_runs alter column package_id set not null;
#    alter table rpmdiff_waivers alter column run_id set not null;
#    alter table rpmdiff_waivers alter column test_id set not null;
#    alter table rpmdiff_waivers alter column package_id set not null;
# create index package_waiver_idx on rpmdiff_waivers(package_id, test_id);
class RpmdiffWaiverColumns < ActiveRecord::Migration
  def self.up
    add_column :rpmdiff_runs, :package_id, :integer,
    :description => 'Package for Run'
    add_column :rpmdiff_waivers, :run_id, :integer,
    :description => 'Rpmdiff Run for waiver'
    add_column :rpmdiff_waivers, :test_id, :integer,
    :description => 'Rpmdiff Run for waiver'
    add_column :rpmdiff_waivers, :package_id, :integer,
    :description => 'Rpmdiff Run for waiver'

    add_foreign_key "rpmdiff_waivers", ["run_id"], "rpmdiff_runs", ["run_id"]
    add_foreign_key "rpmdiff_waivers", ["test_id"], "rpmdiff_tests", ["test_id"]
    add_foreign_key "rpmdiff_waivers", ["package_id"], "errata_packages", ["id"]
    add_index "rpmdiff_waivers", ["package_id", "test_id"], :name => "package_waiver_idx"
  end

  def self.down
    remove_column :rpmdiff_runs, :package_id
    remove_column :rpmdiff_waivers, :run_id
    remove_column :rpmdiff_waivers, :test_id
    remove_column :rpmdiff_waivers, :package_id
  end
end
