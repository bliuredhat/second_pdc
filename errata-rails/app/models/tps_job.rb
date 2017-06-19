# == Schema Information
#
# Table name: tpsjobs
#
#  job_id     :integer       not null, primary key
#  run_id     :integer       not null
#  arch_id    :integer       not null
#  version_id :integer       not null
#  host       :string(255)   not null
#  state_id   :integer       not null
#  started    :datetime      not null
#  finished   :datetime
#  link       :string(255)   default(""), not null
#  link_text  :string(4000)  default(""), not null

class TpsJob < ActiveRecord::Base
  self.table_name = "tpsjobs"
  self.primary_key = "job_id"

  belongs_to :tps_state,
    :foreign_key => "state_id"

  belongs_to :run,
  :class_name => "TpsRun",
  :foreign_key => "run_id"

  belongs_to :arch
  belongs_to :variant,
    :foreign_key => "version_id"

  belongs_to :errata
  belongs_to :channel
  belongs_to :cdn_repo

  scope :channel_set, where('channel_id is not NULL')
  scope :host_set, where("host != ''")

  scope :with_states, lambda { |*states| where(:state_id => states) }
  scope :not_with_states, lambda { |*states| where("state_id NOT IN (?)", states) }

  scope :not_started, with_states(TpsState::NOT_STARTED)
  scope :not_finished, not_with_states(TpsState::GOOD, TpsState::WAIVED)

  scope :with_type, lambda { |*job_classes| where(:type => job_classes.map(&:to_s)) }

  attr_reader :old_state_id

  validates_presence_of :errata, :arch, :variant, :run

  # On create only otherwise some old records can't be updated (bug 1093205)
  validate :using_rhel_variant, :on => :create
  validate :one_of_rhn_or_cdn_set, :on => :create

  delegate :is_state?, :to => :tps_state

  before_validation(:on => :create) do
    self.state_id = TpsState.default
    self.errata ||= self.run.errata
    self.started = nil
    self.link = ''
    self.link_text = ''
    self.host = ''
    self.set_tps_job_variant
  end

  after_find do
    @old_state_id = self.state_id
  end

  after_update do
    if queue_out_of_date?
      TPSLOG.debug "TPS_JOB_QUEUE_PUBLISH: State changed for job: #{self.job_id} was #{old_state_id} is now #{self.tps_state.id}."
      TpsQueue.schedule_publication
    elsif state_changed?
      TPSLOG.debug "State changed for job: #{self.job_id} was #{old_state_id} is now #{self.tps_state.id}."
    end
  end

  before_update do
    if tps_state.is_completed_state?
      self.finished = Time.now
    elsif [TpsState::BUSY, TpsState::PENDING].include?(tps_state.id)
      self.started = Time.now
    end
  end

  def should_auto_schedule?
    self.errata.should_auto_schedule_tps?(self.rhnqa?)
  end

  # Should be polymorphic. Need to refactor tpsjobs to use type column
  def can_waive?
    return false unless tps_state.state == 'BAD'
    return true if run.errata.status == State::QE && self.rhnqa? == false
    return true if run.errata.status == State::QE && self.rhnqa? && run.errata.rhnqa?
    return false
  end

  def can_unwaive?
    return tps_state.state == 'WAIVED'
  end

  def repo_name
    repo_name = nil
    if is_cdn?
      repo_name = cdn_repo.try(:cdn_content_set_for_tps)
    elsif is_rhn?
      repo_name = channel.try(:name)
    end
    repo_name
  end

  def determine_tps_stream
    self.variant.determine_tps_stream
  end

  def tps_stream
    determine_tps_stream[0].try(:full_name)
  end

  def tps_errors
    determine_tps_stream[1]
  end

  def valid_for_tps?
    # Consider valid if a job can be picked up by a stable system
    # or a job is completed because QE can still run the invalid
    # job manually and the results will get back to ET.
    tps_state.is_completed_state? || tps_errors.empty?
  end

  def reset_fields_for_reschedule
    self.started = Time.now
    self.finished = nil
    self.link = ''
    self.link_text = ''
    self.host = ''
  end

  def reschedule!
    self.tps_state = TpsState.find(TpsState::NOT_STARTED)
    self.reset_fields_for_reschedule
    self.save!
  end

  def unschedule!
    self.state_id = TpsState.default
    self.started = nil
    self.finished = nil
    self.link = ''
    self.link_text = ''
    self.host = ''
    self.save!
  end

  # Note: this is a confusingly named method.
  # (Will be true for cdn_qa jobs as well as rhn_qa jobs and false
  # for rhn_tps and cdn_tps jobs).
  def rhnqa?
    false
  end

  def to_hash
    finished = self.finished ? self.finished.to_s : ''
    output = {
      :job_id => self.id,
      :run_id => self.run_id,
      :arch => self.arch.name,
      :version => self.variant.name,
      :host => self.host,
      :state => self.tps_state.state,
      :started => self.started.to_s,
      :finished => finished,
      :link => self.link,
      :link_text => self.link_text,
      :rhnqa => self.rhnqa?,
      :repo_name => self.repo_name
    }

    if Settings.enable_tps_cdn
      output[:tps_stream] = self.tps_stream
      output[:config] = self.config
    end
    output
  end

  #
  # Defines the csv style line output used in tps.txt and in
  # tps_run#tps_txt_queue_entry.
  #
  # This is a class method with redundant args because of some code in
  # lib/tps/job_queue that calls this that I don't want to refactor yet.
  # Could probably be converted to an instance method with no args (todo).
  #
  def self.tps_txt_queue_entry(job, errata, repo_name)
    # Don't know if try will be really required,
    # but just in case job has no variant or arch,
    # let's not throw throw the exception.
    row = [
      job.id,
      job.run_id,
      job.rhnqa?,
      job.variant.try(:name),
      job.arch.try(:name),
      errata.id,
      errata.errata_type,
      errata.shortadvisory,
      repo_name,
      errata.respin_count,
    ]

    if Settings.enable_tps_cdn
      row << job.tps_stream
      row << job.config
    end

    row.join(',')
  end

  protected

  def set_tps_job_variant
    dist_repo = self.dist_source
    dist_repo_variant = dist_repo.try(:variant)

    # skip if variant is not set
    # Will eventually failed in the variant validation.
    return if dist_repo_variant.nil?

    dist_links = []
    if self.errata.is_legacy?
      link = "#{self.dist_repo_name}_link".classify.constantize
      dist_repo_id_field = "#{self.dist_repo_name}_id"
      product_versions = self.errata.product_versions

      dist_links = link.joins(:variant).where(
        "errata_versions.product_version_id in (?) and #{dist_repo_id_field} = ? and variant_id != ?",
        product_versions, dist_repo, dist_repo_variant)
    end

    self.variant = if dist_links.empty?
      dist_repo.variant.rhel_variant
    else
      dist_links.first.variant.rhel_variant
    end
  end

  private

  def using_rhel_variant
    return if variant.is_rhel_variant?
    errors.add(:variant, "#{variant.name} is not a rhel variant!")
  end

  def one_of_rhn_or_cdn_set
    if channel.blank? && cdn_repo.blank?
      errors.add(:channel, "Either Channel or CDN Repo must be set")
    elsif channel.present? && cdn_repo.present?
      errors.add(:channel, "Cannot set both RHN Channel and CDN Repo")
    end
  end

  def state_changed?
    return @old_state_id != self.tps_state.id
  end

  def queue_out_of_date?
    return false unless state_changed?
    return  @old_state_id == TpsState::NOT_STARTED || self.tps_state.id == TpsState::NOT_STARTED
  end
end
