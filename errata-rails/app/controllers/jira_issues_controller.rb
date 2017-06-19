require 'shared_controller_nav'

# :api-category: Legacy
class JiraIssuesController < ApplicationController
  include SharedControllerNav
  include AdvisoryFinder

  before_filter :jira_issue_label
  before_filter :find_issue
  before_filter :find_errata, :only => [:add_jira_issues_to_errata, :remove_jira_issues_from_errata, :for_errata]
  before_filter :set_index_nav, :only => [:add_jira_issues_to_errata, :remove_jira_issues_from_errata]

  respond_to :html, :json

  #
  # Fetch a JIRA issue.
  #
  # :api-url: /jira_issues/{key}.json
  # :api-method: GET
  #
  # {key} must be the current key of a JIRA issue, in the format "ABC-123".
  #
  # Example response:
  #
  # ```` JavaScript
  # {
  #   "id_jira": 251677,
  #   "key": "JBSEAM-45",
  #   "summary": "Privilege escalation due to unescaped characters in EL",
  #   "is_private": true,
  #   "labels": ["Security","need-qa"]
  # }
  # ````
  def show
    respond_with(@jira_issue)
  end

  def add_jira_issues_to_errata
    redirect_to :action => 'edit', :controller => 'errata', :id => @errata, :anchor => 'idsfixed'
  end

  def remove_jira_issues_from_errata
    unless request.post?
      set_page_title "Remove #{@jira_issue_label} From #{@errata.shortadvisory}"
      @can_be_dropped, @undroppable = @errata.jira_issues.collect {|j| DroppedJiraIssue.new(:errata => @errata, :jira_issue => j)}.partition {|db| db.valid? }
      @can_be_dropped = @can_be_dropped.map(&:jira_issue)
      return
    end

    chosen = get_selected_jira_issues
    if chosen.empty?
      flash_message :alert, "No JIRA issue has been removed"
    else
      dead_jira_issues = JiraIssue.find(chosen)
      dbs = DroppedJiraIssueSet.new(:jira_issues => dead_jira_issues, :errata => @errata)
      if dbs.save
        flash_message :notice, "Removed: #{dead_jira_issues.map(&:key).join(', ')}"
      else
        flash_message :error, "Error dropping JIRA issue: #{dbs.errors.full_messages.join(',')}"
      end
    end
    redirect_to :action => :view, :controller => 'errata', :id => @errata
  end

  #
  # Fetch the list of advisories which reference a certain JIRA issue.
  #
  # :api-url: /jira_issues/{key}/advisories.json
  # :api-method: GET
  #
  # {key} must be the current key of an issue, in the format "ABC-123".
  def errata_for_issue
    @filed_jira_issues = FiledJiraIssue.includes(:errata).where(:jira_issue_id => @jira_issue)
    @errata = @filed_jira_issues.map(&:errata)
    respond_with(@errata)
  end

  #
  # Fetch the JIRA issues associated with an advisory.
  #
  # :api-url: /advisory/{id}/jira_issues.json
  # :api-method: GET
  #
  # Example response:
  #
  # ```` JavaScript
  # [
  #  {
  #    "id_jira": 10523,
  #    "key": "JBSEAM-45",
  #    "summary": "Privilege escalation due to unescaped characters in EL",
  #    "is_private": true,
  #    "labels": ["Security","need-qa"]
  #  },
  #  {
  #    "id_jira": 10622,
  #    "key": "JBEAP-240",
  #    "summary": "Incorrect strings in documentation",
  #    "is_private": false,
  #    "labels": []
  #  }
  # ]
  # ````
  def for_errata
    respond_with(@errata)
  end

  def get_secondary_nav
    if ['add_jira_issues_to_errata', 'remove_jira_issues_from_errata'].include?(params[:action])
      return get_errata_secondary_nav
    end
  end

  def get_errata_secondary_nav
    [
      { :name => "Add #{@jira_issue_label}",
        :controller => :jira_issues,
        :action => :add_jira_issues_to_errata,
        :title => "Add JIRA issue to advisory",
        :id => @errata.id},
      { :name => "Remove #{@jira_issue_label}",
        :controller => :jira_issues,
        :action => :remove_jira_issues_from_errata,
        :title => "Remove JIRA issue from advisory",
        :id => @errata.id}
    ]
  end

  def reconcile_jira_issues
    if request.post?
      errata = Errata.find(params[:id])
      reconcile_list = Set.new
      errata.jira_issues.each { |issue| reconcile_list << issue.key }
      reconciled = JiraIssue.batch_update_from_rpc(reconcile_list) if !reconcile_list.empty?
    end
    redirect_to :action => :view, :controller => :errata, :id => errata
  end

  private
  def jira_issue_label
    @jira_issue_label = JiraIssue.readable_name
  end

  def find_issue
    unless (k = params[:key]).nil?
      @jira_issue = JiraIssue.find_by_key(k)
      redirect_to_error!("JIRA issue #{k} not found.") unless @jira_issue
    end
  end

  def get_selected_jira_issues
    @selected = params[:jira_issue]
    chosen = IssuesController.get_selected_issues(@selected)
  end
end
