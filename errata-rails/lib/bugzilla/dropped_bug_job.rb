# DelayedJob for notifying bugzilla that bugs are dropped from advisory
module Bugzilla
  class DroppedBugJob
    def initialize(id)
      @dropped_bug_id = id
    end

    def perform
      db = DroppedBug.find(@dropped_bug_id)
      comment = "This bug has been dropped from advisory #{db.errata.advisory_name} by #{db.who.to_s}"
      bz = Bugzilla::Rpc.get_connection
      bz.add_comment(db.bug_id, comment)
      db.bug.info "Posted 'bug dropped' comment to Bugzilla"
    end

    def self.enqueue(dropped_bug)
      dj = Delayed::Job.enqueue self.new(dropped_bug.id), 5
      dropped_bug.bug.debug "Enqueued job #{dj.id} to post 'bug dropped' comment to Bugzilla"
    end
  end
end
