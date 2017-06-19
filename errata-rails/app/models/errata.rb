# == Schema Information
#
# Table name: errata_main
#
#  id                 :integer       not null, primary key
#  errata_id          :integer       not null
#  revision           :integer       default(1)
#  errata_type        :string(64)    not null
#  fulladvisory       :string(255)   not null
#  issue_date         :datetime      not null
#  update_date        :datetime
#  release_date       :datetime
#  publish_date_override :datetime
#  synopsis           :string(2000)  not null
#  mailed             :integer       default(0)
#  pushed             :integer       default(0)
#  published          :integer       default(0)
#  deleted            :integer       default(0)
#  qa_complete        :integer       default(0)
#  status             :string(64)    default("UNFILED")
#  resolution         :string(64)    default("")
#  reporter           :integer       not null
#  assigned_to        :integer       not null
#  old_delete_product :string(255)
#  severity           :string(64)    default("normal"), not null
#  priority           :string(64)    default("normal"), not null
#  rhn_complete       :integer       default(0)
#  request            :integer       default(0)
#  doc_complete       :integer       default(0)
#  valid              :integer       default(1)
#  rhnqa              :integer       default(0)
#  closed             :integer       default(0)
#  contract           :integer
#  pushcount          :integer       default(0)
#  class              :integer
#  text_ready         :integer       default(0)
#  pkg_owner          :integer
#  manager_contact    :integer
#  rhnqa_shadow       :integer       default(0)
#  published_shadow   :integer       default(0)
#  current_tps_run    :integer
#  filelist_locked    :integer       default(0), not null
#  filelist_changed   :integer       default(0), not null
#  sign_requested     :integer       default(0), not null
#  security_impact    :string(64)    default("")
#  product_id         :integer       not null
#  is_brew            :integer       default(1), not null
#  status_updated_at  :datetime      not null
#  group_id           :integer
#  created_at         :datetime      not null
#  updated_at         :datetime      not null
#


require 'error_handling/errata_exception'
require 'set'
require 'message_bus/send_message_job'
require 'message_bus/send_msg_job'
class Errata < ActiveRecord::Base
  extend Memoist
  include Comparable

  # see app/models/concerns
  include ModelChild
  include DocumentationWorkflow
  include SecurityWorkflow
  include ErrataWorkflow
  include ErrataDependencyGraph
  include AbidiffTests
  include RpmdiffTests
  include TpsTests
  include ExternalTests
  include ExternalTests::Ccat
  include BlockingListHelper
  include ErrataPush
  include ErrataFileAssociation
  #------------------------------------------------------------------------
  #
  # NB: the release_date field actually defines the embargo_date
  # and is used mainly for RHSA advisories. It might be different
  # to the publish_date_override which specifies the date the advisory
  # is to be published.
  #
  # Beware of older code that uses the "release_date" terminology
  # to refer to what we now call the embargo date.
  #
  # +------------------------+-----------------------+------------------+
  # | Database Field         | Alias/Suggested Use   | Label in UI      |
  # +------------------------+-----------------------+------------------+
  # | release_date           | embargo_date          | "Embargo Date"   |
  # | publish_date_override  | publish_date (*)      | "Release Date"   |
  # +------------------------+-----------------------+------------------+
  #
  # * Actually this is a method. The publish_date_override can be nil,
  # in which case a derived date is used.
  #
  alias_attribute :embargo_date, :release_date
  # (actually don't think we are using this attribute alias anywhere)
  #------------------------------------------------------------------------

  self.table_name = "errata_main"
  self.inheritance_column = "errata_type"

  validates_presence_of :synopsis, :reporter, :product, :release, :package_owner, :manager

  validates_date :release_date,
  :allow_nil => true,
  :allow_blank => true

  validates_date :publish_date_override,
  :allow_nil => true,
  :allow_blank => true

  validate :content_valid

  validate :errata_type_valid

  validate :batch_valid, :if => :batch_id_changed?

  belongs_to :product

  belongs_to :quality_responsibility
  belongs_to :docs_responsibility
  belongs_to :devel_responsibility

  belongs_to :reporter,
    :class_name => "User"

  belongs_to :assigned_to,
    :class_name => "User"

  belongs_to :package_owner,
    :class_name => "User"

  belongs_to :manager,
    :class_name => "User"

  has_one :content,
    :class_name => "Content",
    :foreign_key => "errata_id"

  has_one :doc_reviewer,
  :through => :content

  belongs_to :release,
    :class_name => "Release",
    :foreign_key => "group_id"

  belongs_to :batch

  has_many :comments,
  :order => "created_at asc, id asc",
  :include => [:who]

  has_many :cc_list,
  :class_name => "CarbonCopy",
  :include => [:who],
  :dependent => :destroy

  has_many :filed_bugs,
  :dependent => :destroy

  has_many :bugs,
  :through => :filed_bugs,
  :include => [:package],
  :uniq => true

  has_many :filed_jira_issues,
  :dependent => :destroy

  has_many :jira_issues,
  :through => :filed_jira_issues,
  :uniq => true

  has_many :text_diffs

  has_many :activities,
  :class_name => 'ErrataActivity',
  :foreign_key => 'errata_id'

  has_many :brew_file_meta, :class_name => 'BrewFileMeta'

  has_many :push_jobs

  has_many :release_components

  has_and_belongs_to_many :dependent_errata,
  :join_table => 'advisory_dependencies',
  :foreign_key => 'blocking_errata_id',
  :association_foreign_key => 'dependent_errata_id',
  :class_name => 'Errata'

  has_and_belongs_to_many :blocking_errata,
  :join_table => 'advisory_dependencies',
  :association_foreign_key => 'blocking_errata_id',
  :foreign_key => 'dependent_errata_id',
  :class_name => 'Errata'

  has_many :blocking_issues
  has_many :info_requests
  has_many :rhts_runs

  belongs_to :current_state_index,
  :class_name => 'StateIndex',
  :foreign_key => :current_state_index_id

  has_many :state_indices,
  :order => 'created_at desc, id desc'

  has_one :text_only_channel_list
  alias_attribute :docker_metadata_repo_list, :text_only_channel_list

  has_many :nitrate_test_plans

  belongs_to :state_machine_rule_set

  has_one :live_advisory_name

  attr_accessor(:idsfixed)

  scope :shipped_live, :conditions => { :status => 'SHIPPED_LIVE'}
  scope :new_files, :conditions => { :status => 'NEW_FILES'}
  scope :qe, :conditions => { :status => 'QE'}
  scope :valid_only, where(:is_valid => true)
  scope :rel_prep, :conditions => { :status => 'REL_PREP'}
  scope :push_ready, :conditions => { :status => 'PUSH_READY'}
  scope :in_push, :conditions => { :status => 'IN_PUSH'}
  scope :dropped_no_ship, :conditions => { :status => 'DROPPED_NO_SHIP'}
  scope :active, :conditions => "status not in ('DROPPED_NO_SHIP', 'SHIPPED_LIVE')"
  scope :not_dropped, :conditions => "status != 'DROPPED_NO_SHIP'"

  scope :pre_release, where(:status => ['NEW_FILES', 'QE'])
  scope :batch_blocker, where(:status => ['NEW_FILES', 'QE', 'REL_PREP'], :is_batch_blocker => true)

  scope :with_workflow_guard, lambda {|guard|
    joins(:product,:release).
      where('COALESCE(errata_main.state_machine_rule_set_id, releases.state_machine_rule_set_id, errata_products.state_machine_rule_set_id) IN (?)',
        guard.pluck('DISTINCT state_machine_rule_set_id')
      )
  }
  scope :with_docs_workflow, lambda{ with_workflow_guard(DocsGuard) }

  # (The sql is defined in ErrataFilter because it was planned at one stage to
  # replace the docs queue with a filter, and a advisory list format).
  scope :in_docs_queue,     where(        ErrataFilter::DOCS_QUEUE_FILTER_SQL   )
  scope :not_in_docs_queue, where("NOT (#{ErrataFilter::DOCS_QUEUE_FILTER_SQL})")

  # Not actually using these right now, but perhaps in the future. See also
  # ErrataFilter::DOCS_STATUS_OPTIONS which somewhat duplicates this logic.
  scope :where_docs_not_requested, not_in_docs_queue.where(:doc_complete => false)
  scope :where_docs_requested,     in_docs_queue.    where(:text_ready   => true )
  scope :where_docs_need_redraft,  in_docs_queue.    where(:text_ready   => false)
  scope :where_docs_approved,                        where(:doc_complete => true )
  scope :unembargoed, where('errata_main.release_date is null or errata_main.release_date <= now()')

  scope :with_fulladvisories, lambda { |*fa|
    fa.flatten!
    return where('1=0') if fa.empty?
    where((['fulladvisory LIKE ?'] * fa.length).join(' OR '), *(fa.map{|x| "#{x}-%"}))
  }


  scope :only_legacy, -> {where(errata_type: ErrataType::NON_PDC_TYPES)}
  scope :only_pdc, -> {where(errata_type: ErrataType::PDC_TYPES)}

  before_validation(:on => :create) do
    self.package_owner ||= self.reporter
    self.manager ||= self.package_owner.organization.manager
  end

  before_save do
    if self.is_security?
      self.security_impact = 'Low' if self.security_impact == 'None'
      self.synopsis = "#{self.security_impact}: #{self.synopsis_sans_impact}"
    else
      self.security_impact = 'None'
    end
  end

  before_create do
    self.issue_date = Time.now
    self.update_date = Time.now
    self.status_updated_at = Time.now
    self.revision = 1

    self.status = State::NEW_FILES
    self.content_types = [].to_yaml

    pkg = guess_package
    if pkg
      if self.quality_responsibility.nil? || self.quality_responsibility.name == 'Default'
        self.quality_responsibility = pkg.quality_responsibility
      end
      if self.docs_responsibility.nil? || self.docs_responsibility.name == 'Default'
        self.docs_responsibility = pkg.docs_responsibility
      end
      if self.devel_responsibility.nil? || self.devel_responsibility.name == 'Default'
        self.devel_responsibility = pkg.devel_responsibility
      end
      if self.assigned_to.nil? || self.assigned_to_default_qa_user?
        self.assigned_to = pkg.quality_responsibility.default_owner
      end
    else
      self.quality_responsibility ||= QualityResponsibility.find_by_name('Default')
      self.docs_responsibility ||= DocsResponsibility.find_by_name('Default')
      self.devel_responsibility ||= DevelResponsibility.find_by_name('Default')
    end

    self.assigned_to ||= User.default_qa_user
    set_batch_for_release
  end

  before_update do
    if status_changed?
      idx = current_state_index
      unless idx.previous == status_was && idx.current == status
        raise "State change does not match current state index: #{status_was} => #{status} " +
          "vs #{idx.previous} => #{idx.current}"
      end
    end

    if self.fulladvisory.nil? || self.revision_changed? || self.errata_type_changed?
      self.set_fulladvisory
    end

    set_batch_for_release if group_id_changed?

    if text_only_changed?
      @content_types = nil
      self.content_types = generate_content_types.to_yaml
    end
  end

  after_create do
    fa = self.set_fulladvisory
    self.update_column(:fulladvisory, fa)

    cc_list.create(:who => User.default_qa_user)
    idx = StateIndex.create!(:errata => self,
                             :who => self.reporter,
                             :previous => '',
                             :current => 'NEW_FILES')
    self.current_state_index = idx
    # ensure callbacks aren't re-fired, as Dirty attributes will not be consistent
    # in after_create. Replace with update_column when update to Rails >= 3.1
    unless Errata.update_all({ :current_state_index_id => idx }, :id => self.id ) == 1
      raise "Error creating initial state index"
    end

    msg = { 'who' => self.reporter.login_name,
      'when' => self.created_at.to_s,
      'errata_id' => self.id,
      'type' => self.errata_type,
      'release' => self.release.name,
      'synopsis' => self.synopsis
    }
    MessageBus::SendMessageJob.enqueue(msg, 'created', self.is_embargoed?)

    msg_header = {
      'subject' => 'errata.activity.created',
      'who' => self.reporter.login_name,
      'when' => self.created_at.to_s,
      'errata_id' => self.id,
      'type' => self.errata_type,
      'release' => self.release.name,
      'synopsis' => self.synopsis
    }

    msg_body = {
      'who' => self.reporter.login_name,
      'when' => self.created_at.to_s,
      'errata_id' => self.id,
      'type' => self.errata_type,
      'release' => self.release.name,
      'synopsis' => self.synopsis
    }

    MessageBus.enqueue(
      'errata.activity.created', msg_body, msg_header,
      :embargoed => self.is_embargoed?,
      :material_info_select => 'errata.activity'
    )

    self.comments << BatchChangeComment.new(
      :text => "Advisory batch set to '#{self.batch.name}' (next batch for release '#{self.release.name}')",
    ) if self.batch
  end

  after_save do
    if self.text_only?
      self.text_only_channel_list ||= TextOnlyChannelList.create(:errata => self)
    end
  end

  def self.with_unembargoed_scope
    self.with_scope(:find => unembargoed) do
      yield
    end
  end

  def advisory_name
    return short_errata_type + "-" + shortadvisory
  end

  def oval_errata_id
    matches = self.fulladvisory.match(/-(\d{4}):(\d+)-(\d+)$/)
    raise ArgumentError, "Invalid full advisory '#{self.fulladvisory}'" if matches.nil?
    return "#{matches[1]}#{matches[2]}"
  end

  # Need this for group by devel group in filters,
  # because group by requires an Errata method to use for grouping.
  def package_owner_organization
    package_owner.organization
  end

  #
  # See Bug 978077.
  #
  # self.state_machine_rule_set is usually nil which means use the default.
  #
  # Want to make sure that we don't break the model attribute behaviour
  # so define a new getter based on the original state_machine_rule_set method.
  # (Maybe there's a better way to do this...)
  #
  alias_method :custom_state_machine_rule_set, :state_machine_rule_set
  def state_machine_rule_set
    custom_state_machine_rule_set || default_state_machine_rule_set
  end

  # Default rule set comes from the release or product
  def default_state_machine_rule_set
    release.state_machine_rule_set || product.state_machine_rule_set
  end

  # NB: If custom rule set is present but identical to the default rule set
  # then is false (in contrast to custom_state_machine_rule_set.present?).
  def has_custom_state_machine_rule_set?
    state_machine_rule_set != default_state_machine_rule_set
  end

  def allow_partner_access?
    return false unless product.notify_partners?

    # Beyond above check, the criteria are identical for allowing pre-push.
    prepush_blockers.empty?
  end

  # This sometimes returns inactive product versions, depending on whether
  # the product versions are retrieved from the release or the product
  def available_product_versions
    product_versions = []
    if self.release.product_versions.empty?
      # Note: this always returns enabled product versions
      product_versions = self.product.product_versions
    else
      if self.release.product.nil?
        product_versions = self.release.product_versions.where('product_id = ?', self.product)
      else
        product_versions = self.release.product_versions
      end
    end
    product_versions.reject! {|pv| pv.variants.empty?}
    return product_versions.sort {|a,b| a.name <=> b.name}
  end

  def active_channels_and_repos_for_available_product_versions
    [active_channels_for_available_product_versions,
     active_cdn_repos_for_available_product_versions].flatten
  end

  def active_channels_for_available_product_versions
    available_product_versions.map(&:active_channels).flatten.uniq
  end

  def active_cdn_repos_for_available_product_versions
    available_product_versions.map(&:active_repos).flatten.uniq
  end

  def docker_metadata_repos
    docker_metadata_repo_list.try(:get_cdn_repos) || []
  end

  #
  # Returns a list of nvrs for builds in this errata grouped by
  # product_version. (Previously BrewController#current_builds_for_errata).
  #
  def build_nvrs_by_product_version
    builds_hash = HashList.new

    build_mappings.each do |errata_brew_mapping|
      (builds_hash[errata_brew_mapping.product_version] << errata_brew_mapping.brew_build.nvr).uniq!
    end

    builds_hash
  end

  def build_files_by_nvr_variant_arch
    hsh = HashList.new

    # This supports RPM and Docker image files only
    mappings = has_docker? ?
      build_mappings.tar_files.select(&:has_docker?) :
      build_mappings.for_rpms

    mappings.each do |m|
      pv_name = m.product_version.name
      build_info = Hash.new { |hash, key| hash[key] = {}}
      nvr = m.brew_build.nvr
      build_info[nvr] = {}
      m.get_file_listing.each do |f|
        build_info[nvr][f.variant.name] ||= HashList.new
        build_info[nvr][f.variant.name][f.arch.name] << f.brew_rpm.filename
      end
      hsh[pv_name] << build_info
    end
    hsh
  end

  #
  # This is not very efficient probably.
  # Want a way to have canonical anchor for #c123 urls.
  # Previously it was sensitive to display order.
  # This is one quick hacky way to do it.
  #
  # (The +1 is just so user sees the first comment as comment
  # one instead of comment zero).
  #
  # I can't reproduce it, but we sometimes get an exception
  # where comments.index(comment) is nil. It seems like
  # that might happen if the comment is a brand new one
  # and self.coments is cached in some way and doesn't yet
  # include the new comment. Let's assume that is the case
  # and give it an index of comments.length + 1 instead of
  # throwning an exception.
  #
  def comment_index_canonical(comment)
    # Comments are sorted by created_at, see above
    comment_index = comments.index(comment)
    if comment_index
      # Normal case
      comment_index + 1
    else
      # Prevent unusual exception, see comments above
      comments.length + 1
    end
  end

  def brew_builds_by_product_version
    mappings = self.build_mappings
    return Hash.new() if mappings.empty?

    versions = Hash.new { |hash, key| hash[key] = []}
    mappings.each do |m|
      (versions[m.product_version] << m.brew_build).uniq!
    end
    return versions
  end

  def brew_rpms
    @_brew_rpms ||= self.brew_files(build_mappings.for_rpms)
  end

  def container_content
    @container_content ||= Metaxor.new(:warn_on_error => true).container_content_for_builds(brew_builds)
  end

  def container_errata
    @container_errata ||= container_content.values.map{|v| v.try(:errata)}.flatten.uniq.compact
  end

  def has_container_errata?
    container_errata.any?
  end

  def has_active_container_errata?
    container_errata.any?(&:is_active?)
  end

  # Want a reload to result in brew_rpms being refreshed
  # (Todo: refactor and put in a module for reuse)
  def reload(*args)
    @_brew_rpms = nil
    @container_content = nil
    @container_errata = nil
    @has_nonrpms = nil
    @has_rpms = nil
    @has_docker = nil
    @has_brew_files_requiring_meta = nil
    @memo = nil
    @relarchlist = nil
    super
  end

  def brew_files(for_mappings = nil)
    ids = brew_files_by_build_mappings(for_mappings).
      select("distinct brew_files.id").
      map{|m| m.attributes["id"]}
    BrewFile.where(:id => ids)
  end

  def has_docker?
    if @has_docker.nil?
      @has_docker = brew_files.tar_files.any?(&:is_docker?)
    end
    @has_docker
  end

  def has_nonrpms?
    if @has_nonrpms.nil?
      @has_nonrpms = brew_files_by_build_mappings(build_mappings.for_nonrpms).any?
    end
    @has_nonrpms
  end

  def has_rpms?
    if @has_rpms.nil?
      @has_rpms = brew_files_by_build_mappings(build_mappings.for_rpms).any?
    end
    @has_rpms
  end

  # returns true if advisory contains brew files
  # that are neither rpms or docker images
  def has_brew_files_requiring_meta?
    if @has_brew_files_requiring_meta.nil?
      @has_brew_files_requiring_meta = brew_files_requiring_meta.any?
    end
    @has_brew_files_requiring_meta
  end

  # files other than rpm or docker images require BrewFileMeta
  def brew_files_requiring_meta
    brew_files.nonrpm.reject(&:is_docker?)
  end

  # returns files for an advisory which should have BrewFileMeta records but don't
  def brew_files_missing_meta
    present_file_ids = brew_file_meta.complete.pluck(:brew_file_id)
    brew_files_requiring_meta.reject{|f| f.id.in?(present_file_ids)}
  end

  def bug_list
    return bugs
  end

  def issue_list
    issues = []
    issues.concat self.bugs.map(&:id)
    issues.concat unambiguous_jira_keys
    issues
  end

  # Returns the most recent StateIndex when this advisory was in the given status
  def last_state_index(status)
    out = StateIndex.where(:errata_id => self, :current => status).order('updated_at DESC').limit(1)
    return out.exists? ? out.first : nil
  end

  def can_respin?
    [State::QE, State::NEW_FILES].include?(self.status)
  end

  def cc_users
    cc_list.map(&:who)
  end

  def cc_emails
    cc_users.map(&:login_name)
  end

  def cc_emails_short
    cc_emails.map{ |email| email.sub('@redhat.com', '') }
  end

  def default_notification_users
    [reporter, package_owner, assigned_to]
  end

  def notify_and_cc_users
    default_notification_users + cc_users
  end

  def notify_and_cc_emails
    notify_and_cc_users.map(&:login_name)
  end

  def change_state!(new_status, who_changed, change_comment = nil)
    StateIndex.create!(:errata => self,
                       :who => who_changed,
                       :previous => self.status.to_s,
                       :current => new_status.to_s)

    msg = "Changed state from #{self.current_state_index.previous} to #{self.current_state_index.current}"
    msg += "\n#{change_comment}" if change_comment

    self.comments << StateChangeComment.new(who: who_changed, text: msg)
  end

  # Returns any private Security Response vulnerability bugs either filed
  # on this advisory or blocked by bugs on this advisory.
  # Does not include transitive blockers.
  def embargoed_bugs
    bug_ids = bugs.pluck('bugs.id')

    bug_ids.concat(BugDependency.
                    where(:bug_id => bug_ids).
                    pluck('distinct blocks_bug_id'))

    Bug.joins(:package).where(:id => bug_ids,
                              :is_security => true,
                              :is_private => true,
                              :packages => {:name => 'vulnerability'})

  end

  def errata_year
    return Time.now.year
  end

  def message_id
    "<errata.#{id}@redhat.com>"
  end

  def has_live_id_set?
    live_advisory_name.present?
  end

  def short_errata_type
    self.class.trim_pdc_prefix(errata_type)
  end

  def self.trim_pdc_prefix(type_string)
    type_string.sub(/^Pdc/, '')
  end

  def self.add_pdc_prefix(type_string)
    "Pdc#{trim_pdc_prefix(type_string)}"
  end

  def self.pdc_maybe(is_pdc)
    (is_pdc ? add_pdc_prefix(self.name) : trim_pdc_prefix(self.name)).constantize
  end

  def set_fulladvisory
    if !self.has_live_id_set?
      # use the year that the erratum was created is better
      year = self.created_at.year
      id_part = self.id
    else
      # use the live id if the erratum has live id
      year = self.live_advisory_name.year
      id_part = self.live_advisory_name.live_id
    end

    id_part = sprintf("%.4d", id_part)
    rev = sprintf("%.2d", self.revision)
    self.fulladvisory = [self.short_errata_type, "#{year}:#{id_part}", rev].join('-')
    return self.fulladvisory
  end

  def Errata.find_by_advisory(advisory)
    raise BadErrataID.new(nil) unless advisory

    errata = nil
    begin
      if advisory.class == Fixnum
        # Pure integer ids
        errata = Errata.find(advisory)
      elsif advisory.match(/([0-9]+):([0-9]+)/)
        # Matches something like 2006:0123 or RHSA-2006:6666
        res = Errata.find(:all, :conditions =>
                          ["fulladvisory like ?", "%#{$1}:#{$2}-%"])
        raise BadErrataID.new("Ambiguous search #{advisory} returned multiple results: #{res.collect { |e| e.fulladvisory}.join(", ")}") if res.length > 1
        errata = res.first
        unless errata
          res = Errata.find(:all, :conditions =>
                            ["old_advisory like ?", "%#{$1}:#{$2}-%"])
          raise BadErrataID.new("Ambiguous search #{advisory} returned multiple results: #{res.collect { |e| e.fulladvisory}.join(", ")}") if res.length > 1
          errata = res.first
        end
      elsif advisory.match(/[^0-9]/)
        # Nothing useful can happen from here if advisory still has non-digit chars
        # in it. (See Bug 749691 for an example).
        raise BadErrataID.new(advisory)
      else
        # String integer value
        errata = Errata.find(advisory.to_i)
      end
      raise BadErrataID.new(advisory) unless errata

    rescue ActiveRecord::RecordNotFound
      raise BadErrataID.new(advisory)
    end

    return errata

  end

  def Errata.unassigned_errata
    where(:assigned_to_id => QualityResponsibility.select([:default_owner_id]).all.map(&:default_owner_id)).active
  end

  def Errata.unassigned_count
    unassigned_errata.count
  end

  def fulltype
    type =  Errata.connection.select_one("select description from errata_types where name = '#{self.errata_type}'" )
    return type['description']
  end

  def fulltype_shorter
    fulltype.sub(/^Red Hat /,'')
  end

  def active_blocking_issue
    @active_blocker ||= blocking_issues.find(:first, :conditions => 'is_active = 1')
  end

  def active_info_request
    @active_info ||= info_requests.find(:first, :conditions => 'is_active = 1')
  end

  def info_requested?
    active_info_request != nil
  end

  def can_clear_blocking_issue?(user)
    return false unless is_blocked?
    user == active_blocking_issue.who || user.in_role?(active_blocking_issue.blocking_role.name, 'admin', 'secalert')
  end

  def can_clear_info_request?(user)
    return false unless info_requested?
    user == active_info_request.who || user.in_role?(active_info_request.info_role.name, 'admin') || user == assigned_to
  end

  def is_active?
    self.is_valid == 1 && self.is_open_state?
  end

  def is_end_to_end_test?
    product.is_end_to_end_test?
  end

  def is_open_state?
    State.open_state?(self.status)
  end

  def is_blocked?
    active_blocking_issue != nil
  end

  def is_critical?
    return false
  end

  def is_embargoed?
    self.embargo_date.present? && self.embargo_date > Time.now
  end

  def not_embargoed?
    !self.is_embargoed?
  end

  # these methods are implemented here rather than in RHSA so they return
  # the correct result for an advisory whose type has been changed and has
  # not yet been persisted.
  def is_security?
    self.errata_type == 'RHSA' || self.errata_type == 'PdcRHSA'
  end

  def is_low_security?
    is_security? && self.security_impact == 'Low' && self.embargo_date.nil?
  end

  # advisories of interest to secalert, because they are RHSA or have CVE
  def is_security_related?
    is_security? || cve.present? || has_container_cves?
  end

  def is_container_advisory?
    has_docker?
  end

  # Returns a list of problems with CVE names in the RHSA.
  # These include CVEs listed only in the cve list or the description, misnamed CVEs using the CAN prefix
  # or the use of boilerplate cve text.
  def cve_problems
    problems = HashList.new

    return problems unless self.is_security?

    # secalert vs non-secalert users are shown slightly different guidance
    is_secalert = User.current_user.in_role?('secalert')

    if (description =~ /he\s*Common\s*Vulnerabilities\s*and/)
      problems[:description] << "Use of the boilerplate text in the description 'The Common Vulnerabilities and Exposures project (cve.mitre.org) assigned the name CVE-XXXX-YYYY to this issue.' is not required for new advisories"
    end

    desc_cve = Set.new
    description.scan(/C[AV][NE]-\d+-\d+/).each do |cve|
      parts = cve.split('-',2)
      desc_cve << parts[1]
      if parts[0] =~ /CAN/i
        problems[:description] << "You have used #{cve} in your description.  You should replace this with CVE-#{parts[1]}"
      end
    end

    obj_cve = Set.new
    cve_list.each do |cve|
      parts = cve.split('-',2)
      obj_cve << parts[1]
      if parts[0] =~ /CAN/i
        problems[:cve] << "You have used #{cve} in the list of CVE names.  You should replace this with CVE-#{parts[1]}"
      end

      unless cve.match(/^CVE-\d{4}-\d{4,}$/)
        problems[:cve] << "#{cve} is not correctly formatted"
      end
    end

    (desc_cve - obj_cve).each do |cve|
      problems[:description] <<  "CVE-#{cve} appears in the description but not in the 'CVE names' list#{'.  (This might be on purpose if you are describing an issue that was previously fixed or not fixed)' if is_secalert}"
    end

    (obj_cve - desc_cve).each do |cve|
      problems[:cve] << "CVE-#{cve} appears in the CVE name list but not in the description#{'.  Please check to make sure this is not an error' if is_secalert}"
    end

    return problems
  end

  # Example usage:
  #   errata.status_is?(:QE)
  def status_is?(status_sym)
    self.status == State.const_get(status_sym.to_s.upcase.to_sym)
  end
  alias :state_is? :status_is?

  # Example usage:
  #   errata.status_in?(:QE,:REL_PREP)
  def status_in?(*status_syms)
    status_syms.flatten.map{ |status_sym| State.const_get(status_sym.to_s.upcase.to_sym) }.include?(self.status)
  end
  alias :state_in? :status_in?

  def shipped_live?
    status_is?(:SHIPPED_LIVE)
  end

  def allow_edit?
    # (Note: You can edit in PUSH_READY but it will trigger a state change back to REL_PREP)
    status_in?(:NEW_FILES, :QE, :REL_PREP, :PUSH_READY)
  end

  def is_signed?
    # Note that non-rpm mappings are irrelevant for signing at the moment
    brew_files.rpm.all?(&:is_signed?)
  end

  def relarchlist
    unless @relarchlist
      @relarchlist = []

      version_arches = Hash.new { |hash, key| hash[key] = Set.new}
      current_files.each do |f|
        version_arches[f.variant.description] << f.arch.name unless f.arch.is_srpm?
      end
      version_arches.keys.sort.each do |release|
        arches = version_arches[release]
        @relarchlist << "#{release} - " + arches.to_a.sort.join(', ')
      end
    end
    return @relarchlist
  end

  #
  # If there is a custom release date then use that,
  # otherwise use the ship date from the release if
  # there is one, otherwise use the default_ship_date
  #
  # NB: We call this field "Release Date" in the UI.
  # (the release_date field is called "Embargo Date")
  #
  def publish_date
    if batch.try(:is_active?)
      batch.release_date
    else
      # We have allow_blank hence can't just `publish_date_override || release_ship_date`
      publish_date_override.present? ? publish_date_override : release_ship_date
    end
  end


  #
  # If publish_date is nil then assume the advisory is async and can go out any time
  #
  def publish_date_passed?
    publish_date.nil? || publish_date < Time.current
  end

  #
  # Used for rendering advisory lists
  #
  def publish_date_for_display
    case status
    when State::DROPPED_NO_SHIP
      nil
    when State::SHIPPED_LIVE
      # Not sure why we can't find some actual_ship_dates
      # Perhaps old data before activities were created?
      actual_ship_date.try(:to_s,:Y_mmm_d) || 'n/a'
    else
      publish_date.try(:to_s,:Y_mmm_d) || (batch.try(:is_active?) ? 'Not set' : 'ASAP')
    end
  end

  # Kind the same as the above but return the date or nil
  def publish_or_ship_date_if_available
    case status
    when State::DROPPED_NO_SHIP
      nil
    when State::SHIPPED_LIVE
      actual_ship_date
    else
      publish_date
    end
  end

  #
  # Also used for rendering (let a user know what type of release date it is)
  #
  def publish_date_explanation
    if status == State::DROPPED_NO_SHIP
      'never released'
    elsif status == State::SHIPPED_LIVE
      'shipped date'
    elsif batch.try(:is_active?)
      'batch'
    elsif publish_date_override.present?
      'custom'
    else
      'default'
    end
  end

  #
  # NB: HAVE MADE A HELPER THAT DUPES THIS
  # but this one is still used in other places
  # TODO, find where and fix it up
  #
  def publish_date_and_explanation
    bold = publish_date_explanation == 'custom'
    html = ''
    html << '<div class="compact">'
    html << '<b>' if bold
    html << [publish_date_for_display,"<small style='color:#888'>(#{publish_date_explanation})</small>"].compact.join('<br/>')
    html << '</b>' if bold
    html << '</div>'
    html.html_safe
  end

  # For sensible tablesort (more messy stuff that wants to be refactored!)
  def publish_date_sort_by
    if publish_date_for_display =~ /ASAP/
      '0000000000000'
    elsif publish_date_explanation =~ /never/
      'ZZZZZZZZZZZZZ'
    else
      publish_date_for_display
    end
  end

  #
  # If the release has no ship date then fall back to the
  # release's default_ship_date (which actually is always
  # nil now, used to be set for fasttrack).
  #
  def release_ship_date
    release.ship_date || release.default_ship_date
  end

  def embargo_date_for_display
    self.embargo_date.try(:to_s,:Y_mmm_d) || 'n/a'
  end

  def shortadvisory
    if new_record?
      self.issue_date = Time.now
      year = errata_year
      return "#{year}:XXXX"
    end

    return fulladvisory.split('-')[1]
  end

  def short_impact
    return ''
  end

  def release_versions_for_brew_build(brew_build)
    build_mappings.where(:brew_build_id => brew_build).map(&:release_version).uniq
  end

  def synopsis_sans_impact
    return synopsis
  end

  def crossref
    return content.crossref
  end

  def cve
    return content.cve
  end

  def cve_list
    return [] if content.cve.blank?
    # content.cve.split(' ') should normally be identical here but let's be defensive
    content.cve.split(/[\s,]+/).reject(&:blank?).sort.uniq
  end

  def container_cves
    container_errata.map(&:cve_list).flatten.sort.uniq
  end

  def has_container_cves?
    is_container_advisory? && container_cves.any?
  end

  def all_cves
    cves = cve_list
    return cves unless is_container_advisory?
    cves.concat(container_cves)
    cves.sort.uniq
  end

  def description
    return content.description
  end

  def keywords
    return content.keywords
  end

  def multilib
    return content.multilib
  end

  def obsoletes
    return content.obsoletes
  end

  def reference
    return content.reference
  end

  def solution
    return content.solution
  end

  def topic
    return content.topic
  end

  def content_valid
    return if content.valid?
    content.errors.each { |attr,msg| errors.add(attr,msg)}
  end

  def batch_valid
    return unless batch
    errors.add(:batch, 'must be active') if !batch.is_active?
    errors.add(:batch, 'is locked') if batch.is_locked?
    errors.add(:batch, 'cannot be released') if batch.is_released?
    errors.add(:batch, 'must be for same release') if batch.release != release
  end

  # This method is not well named but I won't change it now...
  def unassigned?
    QualityResponsibility.where(:default_owner_id => self.assigned_to_id).any? &&
      # Most default owners are mailing lists, but some are real people.
      # Don't want to say "unassigned" when advisory is assigned to a real person,
      # even if they are a default owner. (Quick hack/workaround for Bug 883179)
      self.assigned_to.probably_mailing_list?
  end

  def assigned_to_default_qa_user?
    self.assigned_to == User.default_qa_user
  end

  def verified_bugs
    @verified_bugs ||= bugs.select(&:is_status_verified?)
  end


  #
  # Some utility methods used in app/models/notifier for constructing email subjects
  #
  def quoted_synopsis
    "'#{self.synopsis}'"
  end

  def name_and_release
    "[#{self.advisory_name} #{self.release.name}]" # (notice square brackets)
  end

  def name_release_and_synopsis
    "#{self.name_and_release} #{self.synopsis}"
  end

  #
  # Alternative to name_release_and_synopsis.
  # Chris Ward requested this (kind of) in 462852,
  # but not using it at present.
  #
  def name_release_and_short_title
    "#{self.name_and_release} #{self.short_email_subject_title}"
  end

  #
  # We want a short-ish email subject. Let's use the packages list
  # or the synopsis, which-ever is shorter. Unless there are no packages
  # yet then use the synopsis. But, for RHSA we also want the security_impact
  # field, which might be in the synopsis as well, so remove it first.
  # Simple, huh? See Bugzilla 462852.
  #
  def short_email_subject_title
    # Comma separated list of packages
    # (Got private method error, hence using send. Maybe it should be protected instead? TODO)
    actual_packages_text  = !self.packages.empty?           ? self.packages.join(', ')        : nil
    guessed_packages_text = !self.send(:guess_package).nil? ? self.send(:guess_package).name  : nil

    # Use the best one we have
    packages_text = actual_packages_text || guessed_packages_text || ''

    # Only for security advisories do we include the security_impact
    security_impact_text = (self.errata_type == "RHSA" ? "#{self.security_impact}: " : "")

    # Remove the security_impact_text from the synopsis so it isn't displayed twice
    synopsis_text_trimmed = self.synopsis.sub(/^#{Regexp.escape(security_impact_text)}/,"")

    # Use packages_test if it is shorter (provided there are some packages)
    use_text = if packages_text.blank? || packages_text.length > synopsis_text_trimmed.length
      synopsis_text_trimmed
    else
      packages_text
    end

    # Final result
    "#{security_impact_text}#{use_text}"
  end

  #
  # Before they are shipped only security text only advisories can have a text_only_cpe field,
  # but secalert users can add CPE info to non-RHSA advisories via SecurityController#fix_cpe
  # after they are shipped. See Bug 1104521.
  #
  def can_have_text_only_cpe?
    (self.is_security? || self.shipped_live?) && self.text_only?
  end

  def can_have_product_version_text?
    self.is_security? && self.text_only?
  end

  #
  # Used in the Content before_save to decide if CVEs are allowed.
  # Generally only RHSA advisories have CVEs, however shipped advisories that aren't
  # RHSAs can be given a CVE after they are shipped via SecurityController#fix_cve_names.
  # So we need to permit that. See Bug 881643
  #
  def can_have_cve?
    self.is_security? || self.shipped_live?
  end

  def public_cpe_data_changed?
    return false unless status_changed? && status_is?(:SHIPPED_LIVE)
    !(cve.blank? && content.text_only_cpe.blank?)
  end

  #
  # Don't want to allow editing dependencies
  # when in PUSH_READY or SHIPPED_LIVE or DROPPED_NO_SHIP.
  #
  def can_edit_dependencies?
    status_in?(:NEW_FILES, :QE, :REL_PREP)
  end

  #
  # Whether the batch details for the errata can be edited.
  #
  def can_edit_batch?
    self.release.enable_batching? &&
      status_in?(:NEW_FILES, :QE, :REL_PREP) &&
      User.current_user.can_manage_batches?
  end

  #
  # Can't modify the file list unless we are in NEW_FILES
  #
  def filelist_unlocked?
    status_is?(:NEW_FILES)
  end
  def filelist_locked?; !filelist_unlocked?; end

  #
  # All advisories, which are related to this advisories packages,
  # except ourself.
  #
  def related_advisories_by_pkg
    by_pkg = HashList.new
    self.packages.includes(:errata).each do |p|
      errata = p.errata.flatten.reject{ |e| e == self }
      by_pkg[p] = errata if errata.any?
    end
    return by_pkg
  end
  memoize :related_advisories_by_pkg

  def has_related_advisories?
    related_advisories_by_pkg.any?
  end

  def invalidate_approvals!(opts={})
    self.invalidate_docs_maybe!(opts)
    self.invalidate_security_approval!(opts) unless User.current_user.can_approve_security?
  end

  def errata_public_url
    return "https://access.redhat.com/errata/#{advisory_name}"
  end

  # Return advisory's public url when advisory exists
  # Otherwise, return whatever it is
  def self.public_url(advisory)
    begin
      erratum = Errata.find_by_advisory(advisory)
      return erratum.errata_public_url
    rescue
      return advisory
    end
  end

  def as_json(options = {})
    # as_json will be call by ActiveSupport::JSON for JSON serialization.
    # Deprecated. for backward compatibility only
    new_options = options.merge({:methods => :errata_id})
    super(new_options)
  end

  def to_json(options = {})
    # Deprecated. for backward compatibility only
    new_options = options.merge({:methods => :errata_id})
    super(new_options)
  end

  def errata_id
    # Deprecated. for backward compatibility only
    (self.has_live_id_set?) ? self.live_advisory_name.live_id : self.id
  end

  def reboot_suggested?
    reboot_suggested_with_reasons.first
  end

  # For API compatibility.  (This field used to come from the database, thus was
  # stored as 1 or 0, and now it's a part of our API.)
  def reboot_suggested
    reboot_suggested? ? 1 : 0
  end

  def reboot_suggested_with_reasons
    patterns = (Settings.reboot_suggested_patterns || [])
    matches = []

    current_files.each do |f|
      # Some very old advisories have current files with no brew rpm.
      next unless f.brew_rpm.present?

      patterns.each do |product_pattern, rhel_release_pattern, package_pattern|
        subpackage_name = f.brew_rpm.name_nonvr
        next unless subpackage_name =~ %r{^#{package_pattern}$}

        variant = f.variant
        product = variant.product

        next unless product.short_name =~ %r{^#{product_pattern}$}

        rhel_release = variant.rhel_release
        next unless rhel_release.name =~ %r{^#{rhel_release_pattern}$}

        matches << "Ships #{subpackage_name} to #{rhel_release.name}"
      end
    end

    if matches.empty?
      [false, ["Doesn't ship any reboot-suggested package"]]
    else
      [true, matches.uniq.sort]
    end
  end

  def set_batch_for_release
    # RHSAs do not automatically get assigned to batches
    if !self.release.enable_batching? || self.is_security?
      self.batch = nil
      return
    end

    # Get next batch for release,
    # creating one if necessary
    self.batch = self.release.next_batch!
  end

  def unambiguous_jira_keys
    # Get all JIRA issue keys, prefixing with jira:
    # to make them unambiguous where necessary.
    jira_issues.map(&:key).map do |key|
      Bug.with_alias(key).exists? ? "jira:#{key}" : key
    end
  end

  def product_version_descriptions
    if !text_only?
      product_versions.map(&:description).uniq
    elsif content.product_version_text.present?
      content.product_version_text.split(',').map(&:strip)
    elsif (dists = text_only_channel_list.try(:get_all_channel_and_cdn_repos)).present?
      dists.map(&:product_version).map(&:description).uniq
    else
      [product.name]
    end
  end

  #
  # Array of content types (as strings).
  #
  # This includes all the possible BrewArchiveType names
  # plus 'rpm' and 'docker'.
  #
  # Rails serialize is not used to avoid unnecessary updates
  # to the record: https://github.com/rails/rails/issues/8328
  #
  def content_types
    @content_types ||= YAML.load(read_attribute(:content_types)) rescue nil || generate_content_types
  end

  def update_content_types
    update_attribute :content_types, generate_content_types.to_yaml
  end

  def generate_content_types
    content_types = []
    return content_types if text_only?

    archive_types = build_mappings.pluck(:brew_archive_type_id).uniq
    return content_types if archive_types.empty?

    # Docker images have tar archive type
    if archive_types.delete(BrewArchiveType::TAR_ID)
      content_types << (has_docker? ? 'docker' : 'tar')
    end

    # RPMs have nil brew_archive_type_id
    # compact! returns nil if no change was made
    if archive_types.compact!
      content_types << 'rpm'
    end

    content_types << BrewArchiveType.where(:id => archive_types).pluck(:name)
    content_types.flatten.sort
  end

  private

  def brew_files_by_build_mappings(for_mappings = nil)
    for_mappings ||= build_mappings
    build_mapping_table_name = build_mapping_class.table_name
    joins_sql = %{
      LEFT JOIN brew_files ON
        brew_files.brew_build_id = #{build_mapping_table_name}.brew_build_id AND
        brew_files.brew_archive_type_id <=> #{build_mapping_table_name}.brew_archive_type_id}
    for_mappings.joins(joins_sql)
  end

  def guess_package
    syn = self.synopsis_sans_impact
    if syn =~ /new package:(.+)/
      syn = $1
    end

    pkg_name = syn.split(' ').first
    return Package.find_by_name(pkg_name)
  end
end
