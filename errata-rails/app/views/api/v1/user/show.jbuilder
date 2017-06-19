json.login_name @user.login_name
json.realname @user.realname
json.organization @user.organization_name
json.enabled @user.enabled?
json.receives_mail @user.receives_mail?
json.email_address @user.email
json.roles @user.roles.map(&:name).sort
