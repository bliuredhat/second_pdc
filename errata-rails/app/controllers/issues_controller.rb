require 'shared_controller_nav'
class IssuesController < ApplicationController
  include SharedControllerNav

  before_filter :set_index_nav, :only => [:index, :sync_issue_list]

  respond_to :html, :json

  def index
    set_page_title 'Bug Search'
  end

  def get_secondary_nav
    BugsController.get_secondary_nav
  end

  # Determines whether the provided input is:
  # - bugzilla bug ID
  # - bugzilla bug alias
  # - JIRA issue key
  # - nonexistent
  # ...and redirects to the appropriate action.
  def find_errata_for_issue
    unless request.post?
      redirect_to :action => 'index'
      return
    end

    id = params[:issue][:id_or_key]
    id.strip!

    if id.empty?
      flash_message :error, "Empty issue id!"
      redirect_to :action => 'index'
      return
    end

    if JiraIssue.looks_like_issue_key(id) && JiraIssue.where(:key => id).exists?
      redirect_to :controller => :jira_issues, :action => :errata_for_issue, :key => id
    elsif Bug.looks_like_bug_id(id) && Bug.exists?(id.to_i)
      redirect_to :controller => :bugs, :action => :errata_for_bug, :id => id
    else
      bug = Bug.find_by_alias(id)
      unless bug
        flash_message :error, "No such bug or JIRA issue #{id}. Try #{view_context.link_to('syncing', :action => :sync_issue_list)} the bug/issue first."
        redirect_to :action => 'index'
        return
      end
      redirect_to :controller => :bugs, :action => :errata_for_bug, :id => bug.id
    end
  end

  #
  # Allows the user to paste in a list of Bugzilla bugs and JIRA issues to be synced.
  # (NB: We now have quite a few different ways to reconcile/sync bugs.
  # TODO: Should review and consolidate bug syncing actions and methods).
  #
  def sync_issue_list
    set_page_title 'Sync Bug List'
    if request.post?
      @issue_list= (params[:issue_list]||'').strip.split(/[\s,]+/).uniq
      if @issue_list.any?
        if @issue_list.length > 100
          @issue_list = @issue_list[0...100]
          flash_message :alert, "Limiting to 100 bugs/issues. First id #{@issue_list.first}, last id #{@issue_list.last}. "
        end
        # This method will create bugs/jira issues if they don't exist
        @synced, @invalid_issues = self.class.batch_update_from_rpc(@issue_list)

        jira_count = @synced[:jira_issues].size
        bz_count = @synced[:bugs].size
        invalid_count = @invalid_issues.size

        notice = []
        error = []
        notice << "#{jira_count} issues were synced with JIRA." if jira_count != 0
        notice << "#{bz_count} bugs were synced with Bugzilla." if bz_count != 0
        error << "#{invalid_count} invalid issues were found." if invalid_count != 0
        flash_message :notice, notice.join("\n") if !notice.empty?
        flash_message :error, error.join("\n") if !error.empty?
      else
        flash_message :error, "No valid bugs/issues found."
      end
      # Will render the form instead of redirecting here and show a list
      # of the bugs that were synced.
    end
  end

  # Redirect the bug id to Advisory Eligibility page
  def troubleshoot
     issue_id = params[:issue]
     if Bug.looks_like_bug_id(issue_id)
       redirect_to :controller => :bugs, :action => :troubleshoot, :bug_id => issue_id
       return
     elsif JiraIssue.looks_like_issue_key(issue_id)
       flash_message :error, "Troubleshooter is not available for jira issues"
     elsif issue_id
       flash_message :error, "Bad bug id format: #{issue_id}"
     end
     redirect_to :action => 'index'
  end

  # Create or update a set of Bugzilla bugs or JIRA issues from the given IDs.
  # Each ID may be a be number or a JIRA issue key.
  #
  # An error is raised if any ID can't be resolved as either a JIRA issue key
  # or a bug number.
  #
  # Returns all created or updated bugs/issues.
  def self.batch_update_from_rpc(issue_list)
    issue_set = issue_list.to_set
    to_be_synced = { :jira_issues => [], :bugs => [], :invalid => [] }

    issue_set.each do |issue|
      if JiraIssue.looks_like_issue_key(issue)
        to_be_synced[:jira_issues] << issue
      elsif Bug.looks_like_bug_id(issue)
        to_be_synced[:bugs] << issue
      else
        to_be_synced[:invalid] << issue
      end
    end

    synced = { :jira_issues=> [], :bugs => [] }
    synced[:jira_issues] = JiraIssue.batch_update_from_rpc(to_be_synced[:jira_issues])
    synced[:bugs] = Bug.batch_update_from_rpc(to_be_synced[:bugs])

    return synced, to_be_synced[:invalid]
  end

  def self.get_selected_issues(issues)
    chosen = []
    issues.each_pair {|issue,selected| chosen << issue if selected.to_bool}
    return chosen
  end
end
