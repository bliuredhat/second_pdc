# Matches:
# - I am a "devel" user
# - I am an "admin" user
Given(/^I am a(?:n)? "([^"]*)" user$/) do |user_role|
  @user = method("#{user_role}_user".to_sym).call
  auth_as @user
end

# Matches:
# - I have the ..
# - have the ..
Given(/^(?:I )?have the "([^"]*)" role:$/) do |role|
  @user.add_role role
end

Given(/^(?:I )?have the following roles:$/) do |roles|
  @user.add_roles roles.rows.flatten
end
