# Delayed job to update filed bugs in active errata
require 'message_bus'
module Bugzilla
  class UpdateFiledBugsJob
    include SyncIssues

    SYNC_TYPE = :bugzilla_sync

    def perform
      MessageBus.reconcile(SYNC_TYPE) do |update_since, now|
        update_since ||= 30.minutes.ago
        BUGRECON.info "Checking bugs in system"

        # We expect to have updated bugs via the message bus.
        # Any mismatches may indicate missing messages or an outage in our
        # message bus service - warn about it.
        ok_bugs = []
        outdated_bugs = []
        options = {'include_fields' => ['id','last_change_time']}

        with_checkpoints(SYNC_TYPE, update_since, now, BUGRECON) do |from_date, to_date|
          rpc_bugs = Bugzilla::Rpc.new.bugs_changed_since(from_date, options.merge({'to_date' => to_date}))

          rpc_bugs.each do |b|
            our_bug = Bug.select([:last_updated]).find_by_id(b.bug_id)
            # If our date and BZ's date is not equal or bug not exists, then mark the bug to dirty,
            # so that the UpdateDirtyBugsJob can process them later
            if our_bug.nil? || our_bug.last_updated != b.changeddate
              DirtyBug.mark_as_dirty!(b.bug_id, b.changeddate)
              outdated_bugs << b
            else
              ok_bugs << b
            end
          end
        end

        BUGRECON.info "#{ok_bugs.length} bugs are already up-to-date. #{outdated_bugs.length} bugs are outdated."

        outdated_msg = outdated_bugs[0..9].map(&:bug_id).join(', ')
        if (elided = outdated_bugs.length - 10) > 0
          outdated_msg += ", #{elided} more..."
        end
        BUGRECON.info "Outdated bugs: #{outdated_msg}"
      end
    end

    def next_run_time
      5.minutes.from_now
    end

    def rerun?
      true
    end

    def self.enqueue
      Delayed::Job.enqueue self.new, 5
    end
  end
end
