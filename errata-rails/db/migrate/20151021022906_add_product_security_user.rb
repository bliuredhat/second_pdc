class AddProductSecurityUser < ActiveRecord::Migration
  def up
    login_name = 'secalert@redhat.com'
    unless User.find_by_login_name(login_name)
      # We want to send emails to this address. This requires a user
      # account to exist with receives_mail = 1.
      org = UserOrganization.where(:name => 'Red Hat Product Security').first
      User.create!(:login_name => login_name,
        :realname => 'Red Hat Product Security queue',
        :organization => org,
        :enabled => false,
        :receives_mail => true)
    end
  end

  def down
    # 'secalert@redhat.com' user might already exist.
    # do not delete.
  end
end
