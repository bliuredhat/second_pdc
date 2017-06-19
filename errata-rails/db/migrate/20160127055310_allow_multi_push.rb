# This migration changes the index on push_jobs.pub_task_id. It previously required
# uniqueness. That needs to be removed because multiple push jobs can now reference the
# same pub task, in the multipush case.
class AllowMultiPush < ActiveRecord::Migration
  def up
    remove_the_index
    add_the_index
  end

  def down
    # This is irreversible if any non-unique task IDs have been loaded.
    # Bail out early in that case to avoid doing a partial rollback.
    jobs_with_ids = PushJob.where('pub_task_id is not null')
    total_jobs = jobs_with_ids.count
    total_tasks = jobs_with_ids.count('distinct pub_task_id')

    if total_jobs != total_tasks
      raise ActiveRecord::IrreversibleMigration,
            'Cannot roll back because non-unique pub tasks exist in push_jobs. ' \
            'Manual fixup is required.'
    end

    remove_the_index
    add_the_index(:unique => true)
  end

  def remove_the_index
    remove_index('push_jobs', :name => 'rhn_push_jobs_pub_task_id_index')
  end

  def add_the_index(options = {})
    add_index('push_jobs', ['pub_task_id'],
              options.merge(:name => 'rhn_push_jobs_pub_task_id_index'))
  end
end
