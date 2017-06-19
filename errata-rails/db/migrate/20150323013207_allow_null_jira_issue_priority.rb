class AllowNullJiraIssuePriority < ActiveRecord::Migration
  def up
    change_table(:jira_issues) do |t|
      t.change :priority, :string, :null => true
    end
  end

  def down
    if JiraIssue.where(:priority => nil).exists?
      raise ActiveRecord::IrreversibleMigration.new(
        'JIRA issues with a null priority have been imported; cannot automatically roll back.')
    end

    change_table(:jira_issues) do |t|
      t.change :priority, :string, :null => false
    end
  end
end
