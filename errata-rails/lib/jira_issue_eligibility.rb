module JiraIssueEligibility

  class JiraIssueCheck < ::CheckList::Check
    include CheckList::AdvisoryLinkHelper
  end

  class CheckList < ::CheckList::List

    class PartOfAdvisory < JiraIssueCheck
      order 1
      title 'Not filed?'
      pass { is_rhsa? || @jira_issue.errata.empty? }
      pass_message { is_rhsa? ? "One advisory per issue restriction doesn't apply." : "The issue is not filed on any existing advisory." }
      fail_message { "The issue is filed already in #{@jira_issue.errata.map{|e|advisory_link(e)}.join(", ")}." }

      def is_rhsa?
        @errata && @errata.is_security?
      end
    end

    class Private < JiraIssueCheck
      order 2
      title 'Correct issue visibility?'
      pass { @jira_issue.is_private? || !Settings.jira_private_only }
      pass_message { Settings.jira_private_only ? "The issue is a private issue." : "Issue visibility restrictions are not applied." }
      fail_message { "The issue is a publicly visible issue.  Only private issues may be used." }
      if Settings.jira_private_only
        note 'Errata Tool is currently configured to allow private JIRA issues only.'
      end
    end

  end
end
