class AddConfigToTpsJobs < ActiveRecord::Migration
  def change
    add_column :tpsjobs, :config, :string, :null => false, :default => 'rhn', :description => 'The config that a schedule machine should run. Either rhn or cdn'
  end
end
