module Bugzilla
  class UpdateDirtyBugsJob

    def perform
      dirty_bug_ids = DirtyBug.engage
      BUGLOG.info "Updating #{dirty_bug_ids.size} dirty bugs..."
      Bug.batch_update_from_rpc(dirty_bug_ids, :permissive => true)
      # report failures
      # are there bugs that couldn't be fetched?
      sync_failed = DirtyBug.where(
        :record_id => dirty_bug_ids,
        :status => :engaged).select(:record_id)

      if sync_failed.any?
        failed_bugs = sync_failed.pluck(:record_id)
        BUGLOG.error "UpdateDirtyBugsJob: failed to sync [#{failed_bugs.join(', ')}] "

        # clear off the dirtybug queue if bugs were partially fetched
        # in case of an XMLRPC::Error, no bugs would be fetch so keep
        # the dirty job queue as it is
        # TODO: is there a better way to propagate error and delete the faulty ones
        if failed_bugs.sort != dirty_bug_ids.sort
          BUGLOG.warn "UpdateDirtyBugsJob: deleting failed bugs [#{failed_bugs.join(', ')}]"
          sync_failed.delete_all
        end
      end
      BUGLOG.info "Done update."
    end

    def next_run_time
      Time.now + Settings.bugzilla_dirty_update_delay
    end

    def rerun?
      DirtyBug.any?
    end

    def self.enqueue_once
      obj = self.new
      id = Delayed::Job.enqueue_once obj, 0, obj.next_run_time
      return id
    end
  end
end
