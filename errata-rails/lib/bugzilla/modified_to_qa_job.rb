# DelayedJob for moving bugs from MODIFIED to ON_QA for a given advisory
module Bugzilla
  class ModifiedToQaJob
    def initialize(filed_bug_id, why='(unknown)')
      @filed_bug_id = filed_bug_id
      @why = why
    end
    
    def perform
      unless FiledBug.exists?(@filed_bug_id)
        BUGLOG.warn "Filed bug #{@filed_bug_id} no longer exists. Cannot move to ON_QA"
        return
      end
      fb = FiledBug.find(@filed_bug_id)
      checklist = fb.move_to_on_qa_checklist
      if checklist.pass_all?
        fb.bug.debug "Moving bug to ON_QA due to #{@why}"
        fb.bug.with_error_log 'Moving bug to ON_QA failed' do
          bz = Bugzilla::Rpc.get_connection
          bz.mark_bug_on_qa(fb.bug, fb.errata)
        end
        fb.bug.info "Moved bug to ON_QA due to #{@why}"
      else
        fb.bug.debug "Not moving bug to ON_QA (due to #{@why}), because: #{checklist.fail_text}"
      end
    end
    
    def self.enqueue(filed_bug, why='(unknown)')
      checklist = filed_bug.move_to_on_qa_checklist
      if checklist.pass_all?
        dj = Delayed::Job.enqueue ModifiedToQaJob.new(filed_bug.id, why), 5
        filed_bug.bug.debug "Queued MODIFIED => ON_QA job #{dj.id} due to #{why}"
      else
        filed_bug.bug.debug "Not queuing move to ON_QA job (due to #{why}), because: #{checklist.fail_text}"
      end
    end
  end
end
