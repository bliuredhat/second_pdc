#
# Add notify_same_role flag to roles.
#
# If this flag is set, blocking issue or info request emails
# will get sent to the role target (if defined).
#
# If this flag is false, emails will not be sent if the user
# making the request has the same role.
#
# Defaults to true so existing functionality is preserved.
#
# See bug: 1259230
#
class AddNotifySameRoleToRoles < ActiveRecord::Migration
  def change
    add_column :roles, :notify_same_role, :boolean, :default => true, :null => false
  end
end
