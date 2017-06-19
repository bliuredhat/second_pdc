class JiraIssue < ActiveRecord::Base
  belongs_to :jira_security_level
  has_many :filed_jira_issues
  has_many :errata,
  :through => :filed_jira_issues

  has_many :dirty_jira_issues, :primary_key => :id_jira, :foreign_key => :record_id

  alias_attribute :security_level, :jira_security_level
  alias_attribute :display_id, :key

  scope :unfiled, :conditions => 'jira_issues.id not in (select jira_issue_id from filed_jira_issues)'
  scope :only_private, joins(:jira_security_level) \
                     .where('jira_security_levels.effect != ?', 'PUBLIC')
  scope :only_public, joins('LEFT JOIN jira_security_levels jsl ON jsl.id=jira_issues.jira_security_level_id') \
                     .where('jira_security_level_id IS NULL OR jsl.effect = ?', 'PUBLIC')

  serialize :labels, JSON
  before_validation do
    self.labels ||= []
    # uniq to silently throw away duplicates, same as JIRA itself does.
    # sort to ensure same set of labels gives same value in this column so that labels
    # can be easily compared/grouped
    self.labels = labels.uniq.sort
  end

  RPC_FIELDS = %w{id key security summary status updated labels priority}
  RPC_EXPAND = %w{security status priority}

  def self.looks_like_issue_key(str)
    str =~ /^[A-Z0-9]+-[0-9]+$/
  end

  def self.readable_name
    "JIRA Issue"
  end

  def self.base_url
    @@_base_url ||= Settings.non_prod_bug_links ? Jira::JIRA_URL : 'https://issues.jboss.org'
  end

  def url
    "#{JiraIssue.base_url}/browse/#{self.key}"
  end

  def self.batch_update_from_rpc(ids, options = {})
    permissive = options.delete(:permissive) || false
    options = batch_update_defaults.merge(options)
    # We allow missing jira issues in rpc query and validate the results later
    options[:validateQuery] = false

    keys = ids.find_all {|id| looks_like_issue_key(id) }

    issues = if keys.empty?
      []
    else
      batch_update_from_jql("key in (#{keys.sort.join ', '})", options)
    end

    unless permissive
      missing_ids = ids.to_set
      issues.each {|issue| missing_ids.delete issue.key}

      if !missing_ids.empty?
        raise Jira::JiraIssueNotExist, "JIRA issue(s) don't exist: #{missing_ids.to_a.join ', '}"
      end
    end

    issues
  end

  def self.batch_update_from_jql(jql, options = {})
    options = batch_update_defaults.merge(options)

    batch_update_search(jql, options).map do |issue|
      JiraIssue.make_from_rpc(issue)
    end
  end

  def self.make_from_rpc(rpc_issue)
    # When matching up an issue from RPC, we consider the issue key as
    # higher priority than the issue's numeric ID.
    #
    # It may seem a little backward, but it makes no difference in the
    # normal production case where the system is only ever connected
    # to one JIRA, and it behaves better in a couple of cases:
    #
    #  - when you use a production DB snapshot imported to a
    #    devel/staging environment, testing against a staging JIRA;
    #    the staging JIRA may generate issues with the same key but
    #    different ID from the production JIRA
    #
    #  - when JIRA projects are migrated from one system to another
    #    (which preserves keys but not IDs)
    #
    # In these cases, if we find an issue with the same key as an
    # existing issue but a different ID, it's preferable that we adopt
    # the existing issue record rather than creating a new record with
    # the same key.
    #
    # See: https://bugzilla.redhat.com/show_bug.cgi?id=1132313
    issue   = JiraIssue.where(:key => rpc_issue.key).first
    issue ||= JiraIssue.where(:id_jira => rpc_issue.id).first_or_initialize

    issue.id_jira = rpc_issue.id
    issue.key = rpc_issue.key
    issue.summary = rpc_issue.summary
    issue.status = rpc_issue.status.name
    issue.updated = DateTime.parse(rpc_issue.updated)
    issue.labels = rpc_issue.fields['labels']
    issue.priority = rpc_issue.priority.try(:name)

    seclevel = rpc_issue.fields['security']
    issue.security_level = JiraSecurityLevel.make_from_rpc(seclevel)

    issue.save!
    issue
  end

  # True if the issue is associated with any non-public security level.
  def is_private?
    !security_level.nil? && security_level.is_private?
  end

  # True if the issue is a Security Response issue or has been labelled as
  # an issue relating to security.
  def is_security_restricted?
    is_security? || labels.include?(Settings.jira_security_label)
  end

  # True if the issue is a Security Response issue.
  # This is always false for JIRA issues.  The method is provided to be
  # API-compatible with Bug.
  def is_security?
    false
  end

  def can_close?
    return false if is_security?
    self.status != Settings.jira_closed_status
  end

  def to_s
    return "#{key} - #{summary} - #{status}"
  end

  def dirty?
    dirty_jira_issues.any?
  end

  private
  def self.batch_update_defaults
    {
      :batch_size => 200,
    }
  end

  def self.batch_update_search(jql,options)
    search_options = {
      :fields => RPC_FIELDS,
      :expand => RPC_EXPAND,
      :jql => jql,
    }.merge(options)
    Jira::Rpc.get_connection.searched_issues(search_options)
  end
end
