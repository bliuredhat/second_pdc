#
# Update blocking_issue_target and info_request_target
# for the secalert role.
#
# Set notify_same_role to false, so email notifications
# are only sent for users who do not have secalert role.
#
# See bug: 1259230
#
class UpdateSecalertNotifyTargets < ActiveRecord::Migration
  def up
    email = 'security-response@redhat.com'

    Role.find_by_name(:secalert).update_attributes(
      :blocking_issue_target => email,
      :info_request_target => email,
      :notify_same_role => false
    )
  end

  def down
    Role.find_by_name(:secalert).update_attributes(
      :blocking_issue_target => nil,
      :info_request_target => nil,
      :notify_same_role => true
    )
  end
end
