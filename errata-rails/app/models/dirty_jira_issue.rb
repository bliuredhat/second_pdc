class DirtyJiraIssue < DirtyRecord
  # It uses 'id_jira' column as primary_key in jira_issues table instead of id
  # column because 'id_jira' is the JIRA unique identifier that ET will receive
  # from by the JIRA message bus.
  belongs_to :jira_issue, :primary_key => 'id_jira', :foreign_key => 'record_id'

  alias_attribute :id_jira, :record_id

  def self.engage
    max = Settings.max_jira_issues_per_sync || 1000
    super(max)
  end
end
