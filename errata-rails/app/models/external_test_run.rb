class ExternalTestRun < ActiveRecord::Base
  include ActiveInactive

  # This isn't ideal. Not sure where else to
  # put these methods that are specific to Covscan
  # so throw them in this concern with a prefix.
  include ExternalTestRunCovscan
  include ExternalTestRunCcat

  belongs_to :external_test_type
  belongs_to :errata
  belongs_to :brew_build

  serialize :external_data, Hash

  # Not currently using this but maybe it's useful if a test run is rescheduled
  # It can mark the run as superseded by a later test run.
  belongs_to :superseded_by, :class_name => "ExternalTestRun"

  validates_presence_of :errata, :external_test_type
  validates_uniqueness_of :external_id, :scope => :external_test_type_id, :if => lambda { external_id.present? }

  validate :errata_supports_test_type, :on => :create

  delegate :name, :display_name, :info_url, :display_name, :toplevel_name, :to => :external_test_type

  scope :of_type, lambda { |test_type| where(:external_test_type_id => ExternalTestType.get(test_type)) }
  scope :with_external_id, where('NOT external_id IS NULL')

  # Beware: This will not necessarily return the same pub targets configured in
  # Settings.pub_push_targets. This is data which will be replayed back to the
  # external test in cases like re-scheduling.
  def pub_target
    external_data['pub_target']
  end

  def pub_target=(val)
    external_data['pub_target'] = val
  end

  # Using the active field as a synonym for current
  def self.current
    self.active
  end

  def self.passing_statuses
    %w[PASSED WAIVED INELIGIBLE]
  end

  def self.failed_statuses
    %w[FAILED]
  end

  def self.find_run(test_type, ext_id)
    self.find_by_external_test_type_id_and_external_id(ExternalTestType.get(test_type).id, ext_id)
  end

  def issue_url
    m = external_message.present? && external_message.match(rcm_jira_issue_regex)
    m[1] if m
  end

  def run_url
    url = external_test_type.run_url_template.dup

    external_id_s = external_id.to_s

    # ID must be used somehow; if not within the template, it's assumed
    # appropriate to append it
    unless url.gsub!(/\$ID/, external_id_s)
      url += external_id_s
    end

    url.gsub!(/\$ERRATA_ID/, errata_id.to_s)

    url
  end

  def passed_ok?
    ExternalTestRun.passing_statuses.include?(status)
  end

  def failed?
    ExternalTestRun.failed_statuses.include?(status)
  end

  def errored?
    status == 'ERROR'
  end

  def last_good_run
    # Todo: No idea how to do this at the moment...
  end

  def type_is?(test_type)
    external_test_type == ExternalTestType.get(test_type)
  end

  # Might be a better way to do this...
  def get_errata_brew_mapping
    self.errata.build_mapping_class.find_by_errata_id_and_brew_build_id(errata_id, brew_build_id)
  end

  # Is the scan for a build that is still current?
  # (We don't want it to be rescheduled otherwise)
  def brew_build_still_current?
    self.errata.build_mappings.include?(self.get_errata_brew_mapping) && self.errata.is_active?
  end

  def reschedule_permitted?(current_user)
    # Yikes!
    case external_test_type.name
    when "ccat"
      type_permitted = issue_url.present? && failed?
    when "covscan"
      type_permitted = (brew_build_still_current? &&
                        (errored? && current_user.can_reschedule_errored_covscan?) ||
                        current_user.can_reschedule_covscan? )
    else
      type_permitted = false
    end

    type_permitted && external_test_type.reschedule_supported? &&
      superseded_by.nil?
  end

  def can_update_status?
    external_id.present? && type_is?(:covscan)
  end

  private

  def errata_supports_test_type
    unless self.errata.requires_external_test?(external_test_type)
      errors.add(:external_test_type, "The '#{display_name}' test is not applicable to this advisory.")
    end
  end

  def rcm_jira_issue_regex
    /(#{Regexp.escape(Settings.rcm_jira_issue_url % '')}[A-Z]+-\d+)/
  end

end
