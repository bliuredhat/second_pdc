class ErrataResponsibilities < ActiveRecord::Migration
  def self.up
    
    create_table "errata_responsibilities",
    :description => 'Organization of advisories by packages, groups and roles.' do |t|
      t.column "name", :string, :null => false,
      :description => "Name of the responsibility group"
      
      t.column "type", :string, :null => false,
      :description => "Type of the group (Quality, Docs, Devel Responsibility)"

      t.column "default_owner_id", :integer, :null => false,
      :description => 'Default owner of this package group. Foreign key to users(id).'

      t.column "user_organization_id", :integer,
      :description => 'Optional link to user organization. Foreign key to user_organizations(id).'
      
      t.column "created_at", :datetime, :null => false,
      :description => 'Creation timestamp'
      
      t.column "updated_at", :datetime, :null => false,
      :description => 'Update timestamp'
    end
    
    add_foreign_key "errata_responsibilities", ["default_owner_id"], "users", ["id"]
    add_foreign_key "errata_responsibilities", ["user_organization_id"], "user_organizations", ["id"]

  end

  def self.down
    drop_table :errata_responsibilities
  end
end

