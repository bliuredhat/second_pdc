class DroppedBug < ActiveRecord::Base
  include DroppedLink
  belongs_to :bug
  alias :target :bug

  after_create do
    msg = { 'who' => self.who.login_name,
      'bug_id' => self.bug_id,
      'when' => self.created_at.to_s,
      'errata_id' => self.errata_id}
    MessageBus::SendMessageJob.enqueue(msg, 'bugs.dropped', self.errata.is_embargoed? || self.bug.is_private? || self.bug.is_security?)
    Bugzilla::DroppedBugJob.enqueue self
    bug.info "Removed from advisory #{errata_id}"
  end
end
