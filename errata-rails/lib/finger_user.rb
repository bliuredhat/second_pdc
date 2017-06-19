#
# Use the system finger command to look up a user.
# Used in UserController when adding a new user account.
#
# Note: Maybe we should use Orgchart for this instead,
# though in the longer term, we should do a nightly sync of
# all Red Hat staff user accounts from LDAP or Orgchart or
# somewhere. Then new Red Hat staff would get an Errata Tool
# account automatically created (but as a 'disabled' account
# so actual access to Errata Tool is still not automatic).
#
class FingerUser
  def initialize(username)
    @username = username
  end

  def stripped_username
    @username.strip.downcase.sub(/@redhat.com/,'')
  end

  def finger_command
    %x{finger -m #{stripped_username} 2> /dev/null | head -1}
  end

  def parsed_finger_output
    # Example finger_command output looks like these:
    #  Login: sbaird         \t\t\tName: Simon Baird
    #  Login: ldelouw        \t\t\tName: Luc De Louw
    finger_command.match(/^Login: (\S+)\s+Name: (.*)$/)
  end

  def name_hash
    if parsed = parsed_finger_output
      { :login_name => "#{parsed[1]}@redhat.com", :realname => parsed[2] }
    else
      nil
    end
  end
end
