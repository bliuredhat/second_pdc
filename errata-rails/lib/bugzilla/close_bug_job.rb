# DelayedJob for closing bugs in SHIPPED_LIVE advisories
module Bugzilla
  class CloseBugJob
    def initialize(filed_bug_id)
      @filed_bug_id = filed_bug_id
    end
    
    def perform
      f = FiledBug.find @filed_bug_id, :include => [:bug, :errata]
      rpc = Bugzilla::Rpc.new
      if f.bug.can_close?
        f.bug.debug "Closing bug (for advisory #{f.errata.id})"
        f.bug.with_error_log 'Closing bug failed' do
          rpc.closeBug(f.bug, f.errata)
        end
        f.bug.info "Closed bug (for advisory #{f.errata.id})"
      elsif f.bug.is_security?
        f.bug.info "Not closing bug - is a security bug.  Adding a comment."
        f.bug.with_error_log 'Adding comment to bug failed' do
          rpc.add_security_resolve_comment(f.bug, f.errata)
        end
      end
    end
    
    def self.close_bugs(errata)
      closeable = errata.filed_bugs.select { |f| f.bug.can_close? || f.bug.is_security? }
      closeable.each { |f| enqueue(f.id) }
    end
    
    def self.enqueue(filed_bug_id)
      dj = Delayed::Job.enqueue CloseBugJob.new(filed_bug_id), 2
      FiledBug.find(filed_bug_id).bug.debug "Enqueued job #{dj.id} to close bug"
    end
  end
end
