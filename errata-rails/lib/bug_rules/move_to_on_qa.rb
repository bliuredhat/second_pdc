module BugRules
  class FiledBugCheck < ::CheckList::Check
    setup do
      @bug = @filed_bug.bug
      @errata = @filed_bug.errata
    end

    def errata_moved_to_qe?
      states = @errata.state_indices.map(&:current)
      qe_idx = states.index('QE')
      new_files_idx = states.index('NEW_FILES') || states.size
      return !qe_idx.nil? && qe_idx < new_files_idx
    end
  end

  class MoveToOnQa < ::CheckList::List
    class Modified < FiledBugCheck
      title 'Bug is MODIFIED?'
      pass { @bug.bug_status == 'MODIFIED' }
      fail_message do
        "Bug status is #{@bug.bug_status}. Only MODIFIED bugs are moved to ON_QA."
      end
    end

    class Security < FiledBugCheck
      title 'Bug is not a Security Response bug?'
      pass { !@bug.is_security? }
      fail_message do
        "This is a Security Response bug, which is never automatically moved to ON_QA."
      end
    end

    class EAPRebaseMoveOnQE < FiledBugCheck
      title 'Advisory moved to QE state? (EAP Rebase bugs only)'
      pass do
        return true unless is_eap_rebase_bug?
        # move to ON_QA if the advisory was in state QE more recently than NEW_FILES
        return errata_moved_to_qe?
      end

      fail_message do
        "This is an EAP Rebase bug, and the associated advisory hasn't moved to QE state - see RFE 1007511."
      end

      def is_eap_rebase_bug?
        @errata.product.short_name == 'JBEAP' && \
          @bug.component.name == 'RPMs' && \
          @bug.has_keyword?('Rebase')
      end
    end

    class MoveBugsOnQE < FiledBugCheck
      title 'Advisory moved to QE state (for products with move_bugs_on_qe flag set)'
      pass do
       return true unless @errata.product.move_bugs_on_qe?
       return errata_moved_to_qe?
      end

      fail_message do
        "Bugs for this product are moved to ON_QA only when advisory moves to QE state."
      end
    end

  end
end
