module MessageBus::Handler::JiraHandler
  extend ActiveSupport::Concern

  included do |klass|
    address = Settings.mbus_jira_address
    props   = Settings.mbus_jira_properties
    klass.subscribe(address, props) do |messages|
      MessageBus::Handler::JiraHandler.handle(messages)
    end
  end

  def self.handle(messages)
    return unless Settings.mbus_jira_sync_enabled
    ids_jira = messages.map{|msg| JSON.parse(msg.body)['id']}
    (to_update,to_create) = ids_jira.to_set.reject(&:nil?).partition{|id_jira|JiraIssue.where(:id_jira => id_jira).exists?}
    update_issues(to_update)
    create_issues(to_create)
  end

  def self.update_issues(ids_jira)
    return if ids_jira.empty?
    mark_dirty_jira_issues(ids_jira)
    JIRALOG.info "Marked #{ids_jira.size} JIRA issues dirty."
  end

  def self.create_issues(ids_jira)
    return if ids_jira.empty?
    mark_dirty_jira_issues(ids_jira)
    JIRALOG.info "Requested creation of #{ids_jira.size} issues."
  end

  private

  def self.mark_dirty_jira_issues(ids_jira)
    # Mark the JIRA issues as dirty, so that the UpdateDirtyIssuesJob can process them later.
    ids_jira.each do |id_jira|
      DirtyJiraIssue.mark_as_dirty!(id_jira)
    end
  end
end
