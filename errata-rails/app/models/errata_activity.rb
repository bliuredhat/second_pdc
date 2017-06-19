# == Schema Information
#
# Table name: errata_activities
#
#  id         :integer       not null, primary key
#  errata_id  :integer       not null
#  who        :integer       not null
#  created_at :datetime      not null
#  what       :string(255)   not null
#  removed    :string
#  added      :string
#

class ErrataActivity < ActiveRecord::Base
  # For any activities listed in here, it is OK to send to the insecure qpid
  # topic, even if the advisory is embargoed.
  #
  # Activities can be listed here if the messages are known to be useful even
  # for embargoed advisories, and the activity doesn't leak information
  # regarding the nature of the advisory.
  INSECURE_ACTIVITIES = %w[
    status
  ]

  # The message related with docs will been sent to the topic "errata.activity.docs_approval"
  DOCS_STATUSES = %w(docs_approved docs_rejected docs_approval_requested)

  belongs_to :who, :class_name => 'User'

  belongs_to :errata

  include Audited

  scope :status_changes, where("what = 'status'")
  scope :to_status,      lambda { |status| where("added = ?", status.to_s) }
  scope :most_recent,    order("created_at DESC").order("id DESC").limit(1)
  after_commit do
    msg = {
      'who'       => self.who.login_name,
      'from'      => self.removed,
      'to'        => self.added,
      'when'      => self.created_at.to_s,
      'errata_id' => self.errata_id,
      'synopsis'  => self.errata.synopsis,
      'fulladvisory' => self.errata.fulladvisory,
    }
    message_is_embargoed = errata.is_embargoed?
    message_is_embargoed = false if INSECURE_ACTIVITIES.include?(what)
    MessageBus::SendMessageJob.enqueue(msg, "activity.#{what}", message_is_embargoed)

    topic, to = if DOCS_STATUSES.include?(what)
      ["errata.activity.docs_approval", what]
    else
      ["errata.activity.#{what}", self.added]
    end

    msg_header = {
      'subject'   => topic,
      'who'       => self.who.login_name,
      'from'      => self.removed,
      'to'        => to,
      'when'      => self.created_at.to_s,
      'errata_id' => self.errata_id,
      'errata_status' => self.errata.status,
      'synopsis'  => self.errata.synopsis,
      'fulladvisory' => self.errata.fulladvisory
    }

    msg_body = {
      'who'       => self.who.login_name,
      'from'      => self.removed,
      'to'        => to,
      'when'      => self.created_at.to_s,
      'errata_id' => self.errata_id,
      'errata_status' => self.errata.status,
      'synopsis'  => self.errata.synopsis,
      'fulladvisory' => self.errata.fulladvisory
    }

    MessageBus.enqueue(
      topic, msg_body, msg_header,
      :embargoed => message_is_embargoed,
      :material_info_select => "errata.activity"
    )

  end
end
