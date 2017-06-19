# -*- coding: utf-8 -*-
# == Schema Information
#
# Table name: bugs
#
#  id            :integer       not null, primary key
#  bug_status    :string(255)   not null
#  short_desc    :string(4000)  not null
#  package_id    :integer       not null
#  is_private    :integer       not null
#  updated_at    :datetime      not null
#  release_notes :text          not null
#  reconciled_at :timestamp
#

class Bug < ActiveRecord::Base
  belongs_to :package
  has_many :filed_bugs
  has_many :errata,
  :through => :filed_bugs

  has_many :dirty_bugs, :foreign_key => :record_id

  alias_attribute :display_id, :id
  alias_attribute :summary, :short_desc
  alias_attribute :status, :bug_status

  has_many :bug_logs, :foreign_key => :record_id
  alias_method :logs, :bug_logs

  has_many :bug_dependencies

  has_many :blocks,
           :through => :bug_dependencies,
           :source => :blocks_bug

  has_many :bug_inverse_dependencies,
           :class_name => 'BugDependency',
           :foreign_key => :blocks_bug_id

  has_many :depends_on,
           :through => :bug_inverse_dependencies,
           :source => :bug

  scope :filed, :conditions => 'bugs.id in (select bug_id from filed_bugs)'
  scope :unfiled, :conditions => 'bugs.id not in (select bug_id from filed_bugs)'
  scope :active, :conditions => "bug_status != 'CLOSED'"
  
  # These two are are not currently used anywhere...
  scope :only_private, :conditions => ['is_private = ?', true  ]
  scope :only_public,  :conditions => ['is_private = ?', false ]

  scope :security_restricted, where("is_security = 1 or keywords like '%Security%'")

  scope :with_states, lambda { |states| where("bugs.bug_status in (?)", states) }

  scope :with_alias, lambda { |al| where(
    'alias LIKE ? OR alias LIKE ? OR alias LIKE ? OR alias = ?',
    "#{al}, %", "%, #{al}", "%, #{al}, %", al)
  }

  #
  # Used in release to get lists of eligible/ineligible bugs
  #
  STATES_FOR_TEST_ONLY = %w[VERIFIED ON_QA]

  ELIGIBLE_BUG_STATE_SQL = "(
      -- not testonly
      NOT (bugs.keywords like '%TestOnly%')
        AND
      bugs.bug_status in (?)
    ) OR (
      -- is testonly bug
      bugs.keywords like '%TestOnly%'
        AND
      bugs.bug_status in (?)
    )"

  scope :eligible_bug_state,   lambda { |states| where(ELIGIBLE_BUG_STATE_SQL,            states, STATES_FOR_TEST_ONLY) }
  scope :ineligible_bug_state, lambda { |states| where("NOT (#{ELIGIBLE_BUG_STATE_SQL})", states, STATES_FOR_TEST_ONLY) }

  #

  validates_presence_of :package

  # This is used as a string in some places, so keep same number of digits
  PRIORITY_ORDER = {
    'urgent' => 10,
    'high' => 20,
    'medium' => 30,
    'med' => 40,
    'unspecified' => 50,
    'low' => 60,
  }.freeze

  STATUS_ORDER = {
    'CLOSED'          => 1,
    'RELEASE_PENDING' => 2,
    'VERIFIED'        => 3,
    'ON_QA'           => 4,
    'MODIFIED'        => 6,
    'ASSIGNED'        => 7,
    'NEW'             => 8,
    'FAILS_QA'        => 91,
    'ON_DEV'          => 92,
    'NEEDINFO'        => 93,
    'POST'            => 94
  }.freeze

  before_create do
    self.is_private ||= 0
    self.pm_score ||= 0
    self.flags ||= ''
    self.qa_whiteboard ||= ''
    self.keywords ||= ''
    self.issuetrackers ||= ''
    self.release_notes ||= ''
    self.verified ||= ''
  end

  before_save do
    self.last_updated = Time.now unless self.last_updated

    # Bugs can have many of the same flag, eg 'needinfo?' or (especially)
    # 'docs_scoped-'. Because we just keep a flat list we can uniq it.
    self.flags = self.flags.split(',').map(&:strip).uniq.sort.join(',')
  end

  def self.looks_like_bug_id(str)
    str.to_s =~ /^[0-9]+$/
  end

  def self.readable_name
    "Bug"
  end

  def self.base_url
    @@_base_url ||= "https://#{Settings.non_prod_bug_links ? Bugzilla::BUGZILLA_SERVER : 'bugzilla.redhat.com'}"
  end

  # The bug's primary URL from the user's point of view
  def url
    "#{Bug.base_url}/show_bug.cgi?id=#{self.id}"
  end

  def bug_id
    return self.id
  end

  def can_close?
    return false if self.is_security?
    return self.bug_status != 'CLOSED'
  end

  def is_security_restricted?
    self.is_security? || self.keywords =~ /Security/
  end

  def keywords_list
    self.keywords.split(/[\s,]+/).reject(&:blank?)
  end

  def has_keyword?(keyword)
    keywords_list.include?(keyword)
  end

  def is_security_tracking?
    has_keyword?('SecurityTracking')
  end

  def is_security_vulnerability?
    is_security? && package.name == 'vulnerability'
  end

  #
  # *** Confusion Warning ***
  #
  # There are now two meanings for the term "verified".
  #
  # The first (and oldest) is based on the bug status
  # and is defined here in is_status_verified? This method
  # is used by Errata#verified_bugs.
  #
  # The second is the contents of the verified attribute,
  # which comes from Bugzilla custom field called 'cf_verified'.
  # This is a string such as 'SanityOnly', 'Adaptec', 'AMD' etc.
  # (See Bz 742132).
  #
  def is_status_verified?
    %w[VERIFIED RELEASE_PENDING CLOSED].include? self.bug_status
  end

  def component_name
    self.package.name
  end

  # 'Component' and 'package' are used synonymously, so let's do this
  def component
    self.package
  end

  # Updates a large set of bug ids from bugzilla. Since
  # Bugzilla has a problem with large lists of bugs,
  # allow handling in batches, defaulting to 500
  def Bug.batch_update_from_rpc(bug_ids, opts = {})
    out = []
    bug_ids.each_slice(opts.delete(:batch_size) || 500) do |list|
      rpc_bugs = Bugzilla::Rpc.new.get_bugs(list, opts)
      out.concat(Bug.make_from_rpc(rpc_bugs))
    end
    out
  end

  # Creates or updates a bug from bugzilla rpc data
  def Bug.make_from_rpc(rpc_bug_or_bugs)
    expect_array = rpc_bug_or_bugs.kind_of?(Array)

    rpc_bugs = Hash.new
    components = []
    Array.wrap(rpc_bug_or_bugs).each do |rpc_bug|
      id = rpc_bug.bug_id
      rpc_bugs[id] = rpc_bug
      components << rpc_bug.component
    end

    changes = []
    unless rpc_bugs.empty?
      # Load all packages in a single query. Create if not found
      packages = Package.find_or_create_packages!(components)

      Bug.where(:id => rpc_bugs.keys).each do |found_bug|
        rpc_bug = rpc_bugs.delete(found_bug.id)
        rpc_bug.errata_package = packages[rpc_bug.component]
        Bug.update_from_rpc(rpc_bug, found_bug)
        changes << found_bug
      end

      rpc_bugs.each_pair do |id, new_bug|
        new_bug.errata_package = packages[new_bug.component]
        changes << Bug.create_from_rpc!(new_bug)
      end
    end

    return expect_array ? changes : changes.first
  end

  # Updates an existing bug from bugzilla rpc data
  def Bug.update_from_rpc(rpc_bug, bug_obj = nil)
    attrs = rpc_bug.to_hash
    begin
      bug = bug_obj.is_a?(Bug) ? bug_obj : Bug.find(rpc_bug.bug_id)
      ActiveRecord::Base.transaction do
        BugDependency.update_from_rpc(rpc_bug)
        bug.update_attributes!(attrs)
      end
      bug.reload
    rescue => e
      logger.error "Updating a bug #{rpc_bug.bug_id} from rpc has failed: #{e.class} #{e.message}"
      nil
    end
  end

  def Bug.create_from_rpc!(rpc_bug)
    ActiveRecord::Base.transaction do
      BugDependency.update_from_rpc(rpc_bug)
      bug = Bug.new(rpc_bug.to_hash)
      bug.id = rpc_bug.bug_id
      bug.save!
      bug
    end
  end

  def has_metadata?
    return is_blocker? || is_exception? || !issuetrackers.empty? || !keywords.empty?
  end

  #
  # See lib/flag_list.rb
  #
  def flags_list
    @flags_list ||= BzFlag::FlagList.new(flags || '')
  end

  def acked_flags_list
    flags_list.select { |flag| flag.state == BzFlag::ACKED }
  end

  # Forces flags_list to be recalculated when flags are modified.
  def flags=(flags)
    @flags_list = nil
    super flags
  end

  #
  # There's no obvious way I know to tell which flag is the release flag,
  # but I think release flags should have a number in them, so let's go with that.
  #
  # The important thing is to exclude the 'fast' flag since Release.with_base_flag('fast')
  # would return many releases. Flags like 'dev_ack' etc are also excluded (even though
  # they would not return anything from Release.with_base_flag because those flags are
  # not stored in the release blocker flag field).
  #
  def self.flag_might_be_release_flag?(flag_name)
    (
      flag_name =~ /[0-9]/ && # should have a number in it
      flag_name != 'fast'     # (redunant, but leave for clarity of intent)
    )
  end

  def potential_release_flags_list
    acked_flags_list.select { |flag| Bug.flag_might_be_release_flag?(flag.name) }
  end

  def possible_releases
    (potential_release_flags_list.map do |flag|
      Release.current.with_base_flag(flag.name)
    end).flatten
  end

  #
  # This is related to 915623.
  # There could be more than one release, but pick one
  # to use initially on the bug troubleshooter page.
  #
  def guess_release_from_flag
    # Make it pick the "obvious" one first
    possible_releases.find { |release| potential_release_flags_list.map(&:name).include?(release.name.downcase) } || possible_releases.first
  end

  #
  # Assume a bug requires doc text unless it has a NACKED requires_doc_text flag
  #
  def doc_text_required?
    flag_state('requires_doc_text') != BzFlag::NACKED
  end

  #
  # Assume a bug's doc text is completed if it has an ACKED requires_doc_text flag
  #
  # Note: The flag is 100% authorative, so doc_text_complete? can be true even
  # if the release_notes field is totally blank, (which might be strange).
  #
  def doc_text_complete?
    flag_state('requires_doc_text') == BzFlag::ACKED
  end

  #
  # Doc text is considered "missing" if it's required but not complete.
  # ("Missing" might not be the exact right word here..).
  #
  def doc_text_missing?
    doc_text_required? && !doc_text_complete?
  end

  #
  # The meaning of has_flag? is actually "has acked flag".
  # Ie, the flag is present AND it is acked.
  #
  def has_flag?(flag)
    flags_list.has_flag?(flag)
  end

  #
  # True if all flags are present and acked
  #
  def has_flags?(flags)
    flags_list.has_all_flags?(flags)
  end

  #
  # Will return '+', '-' or '?' (or false if the flag doesn't exist).
  #
  def flag_state(flag)
    flags_list.flag_state(flag)
  end

  #
  # Find a flag by name
  #
  def find_flag(flag_name)
    flags_list.find_flag(flag_name)
  end

  def to_s
    return "#{id} - #{short_desc} - #{bug_status}"
  end

  def priority_order
    PRIORITY_ORDER[self.priority] || 25
  end

  def status_order
    STATUS_ORDER[self.bug_status] || 0
  end

  def dirty?
    dirty_bugs.any?
  end

  def aliases
    self.alias.to_s.split(',').map(&:strip)
  end

  BugLog.define_log_methods(self)
end
