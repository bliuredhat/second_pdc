# Coordinate the simultaneous addition and removal of a set of issues.
# Used in the 'classic' errata create/edit form in which a list of issue
# keys may be edited to add and/or remove jira issues
class JiraIssueList < IssueListBase
  validate :check_error, :jira_issue_rules

  attr_reader :jira_issues

  alias :list :jira_issues
  alias :keys :ids

  def initialize(ids, errata)
    params = {
      :ids => ids,
      :id_prefix => 'jira:',
      :errata => errata,
      :type => :jira_issues,
      :issue_obj  => JiraIssue,
      :format => :looks_like_issue_key,
      :id_field => :key,
    }

    @to_fetch = super(params)
  end

  def self.message_bus_type
    'JBossJIRA'
  end

  def fetch
    return if @to_fetch.empty?
    fetch_jira_issues_via_rpc(@to_fetch)
  end

  # (Returns nil if we assume the given id doesn't represent a JIRA issue)
  def extract_id(id)
    # User specified it's a JIRA issue
    if id =~ /^jira:(.+)$/
      $1
    # User specified it's a bug
    elsif id =~ /^bz:/
      nil
    # Doesn't resemble an issue key so assume it's not
    elsif !JiraIssue.looks_like_issue_key(id)
      nil
    # Matches a bug alias (and there's no existing JIRA issue that matches)
    elsif Bug.where(:alias => id).exists? && !JiraIssue.where(:key => id).exists?
      nil
    # Assume it's an issue key
    else
      id
    end
  end

  def append(issue_key)
    jira_issue = JiraIssue.find_by_key(issue_key)
    if jira_issue.nil?
      fetch_jira_issues_via_rpc [issue_key]
    else
      @jira_issues << jira_issue
    end
  end

  def find_issues(identifiers)
    JiraIssue.where(:key => identifiers)
  end

  def identifiers_for(issue)
    [issue.key]
  end

  def jira_issue_rules
    params = {
      :filed_target => lambda { |issues, errata| FiledJiraIssueSet.new(:jira_issues => issues, :errata => errata) },
      :dropped_target => lambda { |issues, errata| DroppedJiraIssueSet.new(:jira_issues => issues, :errata => errata) },
    }
    issue_rules(params)
  end

  def persist!
    params = {
      :filed_target => lambda { |issues, errata| FiledJiraIssueSet.new(:jira_issues => issues, :errata => errata) },
      :dropped_target => lambda { |issues, errata| DroppedJiraIssueSet.new(:jira_issues => issues, :errata => errata) },
    }
    save_issues(params);
  end

  private

  def fetch_jira_issues_via_rpc(issue_keys)
    begin
      rpc_jira_issues = JiraIssue.batch_update_from_rpc(issue_keys, :permissive => true)
      @jira_issues.push(*rpc_jira_issues)
    rescue Jira::JiraIssueNotExist => e
      @error_msg = e.message
    end
  end

  def check_error
    errors.add(:idsfixed, @error_msg) if @error_msg
  end
end
