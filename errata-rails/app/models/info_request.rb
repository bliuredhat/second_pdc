class InfoRequest < ActiveRecord::Base
  belongs_to :errata
  belongs_to :state_index
  has_many :comments
  belongs_to :who,
  :class_name => "User"

  belongs_to :info_role,
  :class_name => 'Role',
  :foreign_key => 'info_role'

  validates_presence_of :info_role, :description, :errata, :state_index, :summary, :who

  before_validation(:on => :create) do
    self.who ||= User.current_user
    self.is_active = true
    self.state_index = self.errata.current_state_index
  end

  after_create do
    Notifier.info_request(self).deliver
  end

  def notify_target
    return if !info_role.notify_same_role? && who.roles.include?(info_role)
    info_role.info_request_target
  end
end
