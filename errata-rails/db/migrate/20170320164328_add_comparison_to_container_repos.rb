class AddComparisonToContainerRepos < ActiveRecord::Migration
  def change
    add_column :container_repos,
               :comparison,
               :text,
               :default => nil,
               :null => true
  end
end
