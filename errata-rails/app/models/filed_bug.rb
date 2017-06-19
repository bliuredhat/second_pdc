class FiledBug < ActiveRecord::Base
  include FiledLink
  belongs_to :bug
  alias :target :bug

  scope :in_active_errata,
  :conditions => "errata_id in (select id from #{Errata.table_name} where is_valid = 1 and status not in  ('DROPPED_NO_SHIP', 'SHIPPED_LIVE'))"

  validate(:on => :create) do
    bug_valid
    advisory_state_ok
    security_valid
  end

  after_create :send_messages

  after_destroy do
    DroppedBug.create!(:bug => self.bug,
                      :errata => self.errata,
                      :state_index => self.errata.current_state_index)
  end

  def send_messages
    msg = { 'who' => self.who.login_name,
      'bug_id' => self.bug_id,
      'when' => self.created_at.to_s,
      'errata_id' => self.errata_id}

    embargo_message = self.errata.is_embargoed? || self.bug.is_private? || self.bug.is_security?
    MessageBus::SendMessageJob.enqueue(msg, 'bugs.added', embargo_message)
    bug.info "Added to advisory #{errata_id}"
    Bugzilla::ModifiedToQaJob.enqueue self, "bug added to advisory #{errata_id}"
  end

  def move_to_on_qa_checklist
    BugRules::MoveToOnQa.new(self)
  end

  private

  # For security advisories, secalert users get to skip the bug eligibility tests
  def skip_bug_valid_checks?
    errata.is_security? && (user.in_role?('secalert') || user.is_kernel_developer?)
  end

  def bug_valid
    # TODO: rather than skipping the checks, the checks should be made aware of the RHSA related rules.
    return if skip_bug_valid_checks?
    BugEligibility::CheckList.new(bug, :errata => errata, :release => errata.release).result_list.each do |result, message, title|
      errors.add("Bug ##{bug.bug_id}", message) if !result
    end
  end

  def advisory_state_ok
    return if errata.new_record? || errata.status == State::NEW_FILES
    return if bug.is_security_restricted?
    errors.add(:errata, "Cannot add or remove non-security bugs unless in NEW_FILES state")
  end
end
