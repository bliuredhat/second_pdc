class CreateJobTrackers < ActiveRecord::Migration
  def change
    create_table :job_trackers do |t|
      t.string :name, :null => false
      t.string :description, :null => false
      t.integer :user_id, :null => false
      t.string :state, :null => false, :default => 'RUNNING'
      t.timestamps
    end
  end
end
