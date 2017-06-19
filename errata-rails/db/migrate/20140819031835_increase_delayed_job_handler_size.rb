class IncreaseDelayedJobHandlerSize < ActiveRecord::Migration
  def up
    # Want a mysql `mediumtext` instead of the default `text`
    change_column :delayed_jobs, :handler, :text, :limit => (16.megabytes - 1)
  end

  def down
    change_column :delayed_jobs, :handler, :text
  end
end
