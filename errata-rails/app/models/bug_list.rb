# Coordinate the simultaneous addition and removal of a set of bugs.
# Used in the 'classic' errata create/edit form in which a list of bug
# ids may be edited to add and/or remove bugs
class BugList < IssueListBase

  attr_reader :bugs

  alias :buglist :bugs
  alias :bugids :ids

  validate :bugs_valid, :bug_rules

  def initialize(ids, errata)
    params = {
      :ids => ids,
      :id_prefix => 'bz:',
      :errata => errata,
      :type => :bugs,
      :issue_obj => Bug,
      :id_field => :id,
    }

    @to_fetch = super(params)
  end

  def self.message_bus_type
    'RHBZ'
  end

  def fetch
    return if @to_fetch.empty?
    fetch_bugs_via_rpc(@to_fetch)
  end

  # (Returns nil if we assume the given id doesn't represent a bug)
  def extract_id(id)
    # User specified it's a bug
    if id =~ /^bz:(.+)$/
      $1
    # User specified a it's a JIRA issue
    elsif id =~ /^jira:/
      nil
    # Looks like a JIRA issue and there's a matching JIRA issue and no matching bug alias.
    # (If searching for a JIRA issue key (might be an alias), and bz: prefix was not used,
    # skip the search if this JIRA issue exists.  Otherwise, every attempt to use this
    # JIRA issue will cause a round-trip to Bugzilla to find that the alias doesn't exist.)
    elsif JiraIssue.looks_like_issue_key(id) && JiraIssue.where(:key => id).exists? && !Bug.where(:alias => id).exists?
      nil
    # Assume it's a bug (either an id or an alias)
    else
      id
    end
  end

  # Given some +identifiers+, which in this case could be bug numbers or
  # aliases, find all matching bugs.
  def find_issues(identifiers)
    (ids, aliases) = identifiers.partition do |str|
      str.to_i.to_s == str
    end
    ids.map!(&:to_i)

    sql   = []
    binds = []

    # Aliases are stored in one field, separated by ", ", in the database
    aliases.each do |al|
      sql << 'alias LIKE ? OR alias LIKE ? OR alias LIKE ? OR alias = ?'
      binds += [
        "#{al}, %",
        "%, #{al}",
        "%, #{al}, %",
        al,
      ]
    end

    unless ids.empty?
      sql.prepend('id in (?)')
      binds.prepend(ids)
    end

    if sql.empty?
      # No IDs or aliases - no bugs
      sql = ['1=0']
    end

    Bug.where(sql.join(' OR '), *binds)
  end

  # Given a +bug+, return all the identifiers which could be used to look up that
  # bug via find_issues.
  def identifiers_for(bug)
    out = [bug.id.to_s]
    out += (bug.alias || '').split(/, +/)
    out
  end

  def append(bug_id)
    bug = Bug.find_by_id(bug_id)
    if bug.nil?
      fetch_bugs_via_rpc [bug_id]
    else
      @bugs << bug
    end
  end

  def bug_rules
    params = {
      :filed_target => lambda { |bugs,errata| FiledBugSet.new(:bugs => bugs, :errata => errata) },
      :dropped_target => lambda { |bugs,errata| DroppedBugSet.new(:bugs => bugs, :errata => errata) },
    }
    issue_rules(params);
  end

  def persist!
    params = {
      :filed_target => lambda { |bugs,errata| FiledBugSet.new(:bugs => bugs, :errata => errata) },
      :dropped_target => lambda { |bugs,errata| DroppedBugSet.new(:bugs => bugs, :errata => errata) },
    }
    save_issues(params);
  end

  private

  def fetch_bugs_via_rpc(bug_ids)
    begin
      bz = Bugzilla::Rpc.get_connection
      rpc_bugs = bz.get_bugs bug_ids, :permissive => true
      rpc_bugs.each {|r| @bugs << Bug.make_from_rpc(r)}
    rescue XMLRPC::FaultException => e
      @invalid_bug_ids = e.message
    end
  end

  def bugs_valid
    errors.add(:idsfixed, "Error getting bugs from bugzilla: #{@invalid_bug_ids}") if @invalid_bug_ids
  end
end
