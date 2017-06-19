
class CreateReleasedPackageAudits < ActiveRecord::Migration
  def up
    # table to record all user-updates
    create_table :released_package_updates do |t|
      t.integer :who_id,      :null => false, :references => :users
      t.string  :reason,      :null => false, :limit => 1000
      t.text    :user_input,  :null => false
      t.timestamps
    end

    # join table for user-update vs released_packages
    # one update has many released_packages
    create_table :released_package_audits do |t|
      t.integer :released_package_id, :null => false, :index => true,
                :references => :released_packages

      t.integer :released_package_update_id, :null => false, :index => true,
                :references => :released_package_updates
    end
  end

  def self.down
    drop_table :released_package_audits
    drop_table :released_package_updates
  end
end
