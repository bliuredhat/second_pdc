# DelayedJob for marking bugs as release_pending for a given advisory
module Bugzilla
  class ReleasePendingJob
    def initialize(filed_bug_id)
      @filed_bug_id = filed_bug_id
    end
    
    def perform
      f = FiledBug.find @filed_bug_id, :include => [:bug, :errata]
      bz = Bugzilla::Rpc.get_connection
      bz.mark_bug_as_release_pending(f.errata, f.bug)
    end
    
    def self.enqueue(filed_bug_id)
      Delayed::Job.enqueue self.new(filed_bug_id), 2
    end
    
    def self.mark_bugs_as_release_pending(errata)
      bugs = errata.filed_bugs.find(:all, :conditions => ['bug_id in (select id from bugs where bug_status not in (?))',
                                                          ["RELEASE_PENDING", "CLOSED"]])
      bugs.each { |b| enqueue(b.id)}
    end

    # Renamed the method to mark_bugs_as_release_pending for consistency.
    # Ack/grepping seems to show it is not needed but just in case something
    # external calls this, or it's called indirectly, let's alias the old method.
    class << self
      # (This is how aliasing is done for class methods apparently..)
      alias_method :mark_bugs_release_pending, :mark_bugs_as_release_pending
    end
  end
end
