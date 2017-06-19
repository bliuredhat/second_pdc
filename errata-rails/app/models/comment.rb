# == Schema Information
#
# Table name: comments
#
#  id         :integer       not null, primary key
#  errata_id  :integer       not null
#  who        :integer       not null
#  created_at :datetime      not null
#  text       :text
#

class Comment < ActiveRecord::Base
  belongs_to :who,
    :class_name => "User"

  belongs_to :errata
  belongs_to :state_index
  belongs_to :blocking_issue
  belongs_to :info_request

  #
  # If set to true, CommentSweeper won't send out an automatic email
  # notification.
  #
  # See Bug: 961376
  # Hint: Remove this code if there is a more elegant way to temporarily
  # switch off the command sweeper in order to manually send a
  # notification email on commit.
  #
  attr_accessor(:disabled_notification)

  before_validation(:on => :create) do
    self.who ||= User.current_user
    self.state_index = self.errata.current_state_index unless self.state_index
    if self.errata.active_blocking_issue
      self.blocking_issue = self.errata.active_blocking_issue
    end
    if self.errata.active_info_request
      self.info_request = self.errata.active_info_request
    end
  end

  validates_presence_of :text

  def is_automated?
    who == User.default_qa_user
  end

  def self.create_with_specified_notification_type(notification_type, attrs)
    comment = self.create_without_sweeper(attrs)
    Notifier.send(notification_type, comment).deliver
    return comment
  end

  private

  def self.create_without_sweeper(attrs)
    comment = Comment.new(attrs)
    comment.disabled_notification = true
    comment.save!
    return comment
  end

end

