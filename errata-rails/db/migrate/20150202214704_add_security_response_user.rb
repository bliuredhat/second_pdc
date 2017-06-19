class AddSecurityResponseUser < ActiveRecord::Migration
  def up
    # We want to send emails to this address.  This requires a user
    # account to exist with receives_mail = 1.
    org = UserOrganization.where(:name => 'Security Response Team').first
    User.create!(:login_name => 'security-response@redhat.com',
      :realname => 'Product Security Team queue',
      :organization => org,
      :enabled => false,
      :receives_mail => true)
  end

  def down
    User.where(:login_name => 'security-response@redhat.com', :enabled => false).delete_all
  end
end
