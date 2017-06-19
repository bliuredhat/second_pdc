class ChangeRhnPushJobsToPushJobs < ActiveRecord::Migration
  def self.up
    create_table "push_jobs",
    :description => 'List of all RHN pushes that have occurred. RHN Push is async, so these records are updated until the process terminates.' do |t|
      t.column "errata_id",  :integer,                                       :null => false,
      :description => 'Errata being pushed. References errata_main'
      t.column "pushed_by",  :integer,                                       :null => false,
      :description => 'User pushing the advisory'
      t.column "type",  :string,   :null => false,
      :description => 'Type of push. stage or live'
      t.column "status",     :string,                 :default => "READY", :null => false,
      :description => 'Status of the push. STARTED, FAILED, COMPLETE'
      t.column "created_at", :datetime,                                      :null => false,
      :description => 'Creation timestamp'
      t.column "updated_at", :datetime,                                      :null => false,
      :description => 'Update timestamp'
      t.column "log",        :text,                   :default => "",        :null => false,
      :description => 'Log from RHN Push process'
      t.string :pub_options
      t.string :pre_push_tasks
      t.string :post_push_tasks
      t.integer :priority, :default => 0
      t.integer :pub_task_id
    end

    add_index :push_jobs, :pub_task_id, { :name => 'rhn_push_jobs_pub_task_id_index', :unique => true }
  end

  def self.down
    drop_table :push_jobs
  end
end
