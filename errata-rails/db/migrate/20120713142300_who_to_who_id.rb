class WhoToWhoId < ActiveRecord::Migration
  def self.up
    remove_foreign_key 'comments', 'comments_ibfk_2'
    remove_foreign_key 'carbon_copies', 'carbon_copies_ibfk_2'
    remove_foreign_key 'dropped_bugs', 'dropped_bugs_ibfk_4'
    remove_foreign_key 'errata_activities', 'errata_activities_ibfk_2'
    remove_foreign_key 'nitrate_test_plans', 'nitrate_test_plans_ibfk_2'
    remove_foreign_key 'errata_main', 'assigned_to_fk'
    remove_foreign_key 'errata_main', 'reporter_fk'
    remove_foreign_key 'errata_main', 'manager_contact_fk'
    remove_foreign_key 'errata_main', 'pkg_owner_fk'

    rename_column :comments, :who, :who_id
    rename_column :state_indices, :who, :who_id
    rename_column :carbon_copies, :who, :who_id
    rename_column :dropped_bugs, :who, :who_id
    rename_column :errata_activities, :who, :who_id
    rename_column :info_requests, :who, :who_id
    rename_column :nitrate_test_plans, :who, :who_id
    rename_column :errata_main, :assigned_to, :assigned_to_id
    rename_column :errata_main, :reporter, :reporter_id
    rename_column :errata_main, :pkg_owner, :package_owner_id
    rename_column :errata_main, :manager_contact, :manager_id
  end

  def self.down
    rename_column :comments, :who_id, :who
    rename_column :state_indices, :who_id, :who
    rename_column :carbon_copies, :who_id, :who
    rename_column :dropped_bugs, :who_id, :who
    rename_column :errata_activities, :who_id, :who
    rename_column :info_requests, :who_id, :who
    rename_column :nitrate_test_plans, :who_id, :who
    rename_column :errata_main, :assigned_to_id, :assigned_to
    rename_column :errata_main, :reporter_id, :reporter
    rename_column :errata_main, :package_owner_id, :pkg_owner
    rename_column :errata_main, :manager_id, :manager_contact
  end
end
