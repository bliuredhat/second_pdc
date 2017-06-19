class AddOrgChartIds < ActiveRecord::Migration
  def up
    add_column :users,              :orgchart_id, :integer, :null => true
    add_column :user_organizations, :orgchart_id, :integer, :null => true
  end

  def down
    remove_column :user_organizations, :orgchart_id
    remove_column :users,              :orgchart_id
  end
end
