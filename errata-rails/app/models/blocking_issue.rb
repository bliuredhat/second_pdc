class BlockingIssue < ActiveRecord::Base
  belongs_to :errata
  belongs_to :state_index
  has_many :comments

  belongs_to :who,
    :class_name => "User",
    :foreign_key => "user_id"

  belongs_to :blocking_role,
  :class_name => 'Role',
  :foreign_key => 'blocking_role_id'

  validates_presence_of :blocking_role, :description, :errata, :summary, :who

  before_validation(:on => :create) do
    self.who ||= User.current_user
    self.is_active = true
    self.state_index = self.errata.current_state_index
  end

  after_create do
    Notifier.blocking_issue(self).deliver
  end

  def notify_target
    return if !blocking_role.notify_same_role? && who.roles.include?(blocking_role)
    blocking_role.blocking_issue_target
  end
end
