class MigrateDirtyBugs < ActiveRecord::Migration
  def up
    ActiveRecord::Base.transaction do
      Bug.select('id').where(:dirty => true).each do |bug|
        DirtyBug.create!(:record_id => bug.id, :last_updated => Time.now)
      end
    end

    remove_column :bugs, :dirty
  end

  def down
    add_column :bugs, :dirty, :boolean, :default => false, :null => false, :index => true

    dirty_bug_ids = DirtyBug.pluck("distinct record_id")
    Bug.where(:id => dirty_bug_ids).update_all(:dirty => true)
  end
end
