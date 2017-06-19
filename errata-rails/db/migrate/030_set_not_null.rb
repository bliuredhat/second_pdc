#  delete from product_versions where id = 95;
# update packages set devel_owner_id = 198352, qe_owner_id = 70626 where devel_owner_id is null;

class SetNotNull < ActiveRecord::Migration
  def self.up
    change_column :users, :user_organization_id, :integer, :null => false
    change_column :brew_rpms, :name, :string, :null => false
    change_column :comments, :text, :string, :limit => 4000, :null => false
    change_column :errata_activities, :errata_id, :integer, :null => false
    change_column :errata_main, :group_id, :integer, :null => false
    change_column :errata_main, :status, :string,   :limit => 64,   :default => "UNFILED",:null => false
    change_column :errata_responsibilities, :user_organization_id, :integer, :null => false
    change_column :errata_responsibilities, :url_name, :string, :null => false
    change_column :packages, :devel_owner_id, :integer, :null => false
    change_column :packages, :qe_owner_id, :integer, :null => false
    change_column :product_versions, :rhel_release_id, :integer, :null => false
    change_column :releases, :url_name, :string, :null => false
    change_column :releases, :description, :string, :limit => 4000, :null => false
    change_column :rhel_releases, :description, :string, :limit => 4000, :null => false
    change_column :rpmdiff_runs, :variant, :string, :null => false
    change_column :rpmdiff_runs, :package_id, :integer, :null => false
    change_column :rpmdiff_waivers, :run_id, :integer, :null => false
    change_column :rpmdiff_waivers, :test_id, :integer, :null => false
    change_column :rpmdiff_waivers, :package_id, :integer, :null => false
    change_column :user_groups, :name, :string, :null => false
    change_column :user_groups, :description, :string, :limit => 4000, :null => false
    change_column :user_organizations, :name, :string, :null => false
    change_column :user_organizations, :manager_id, :integer, :null => false
    change_column :user_organizations, :updated_at, :datetime, :null => false
  end

  def self.down

  end
end
