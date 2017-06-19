When(/^I visit "([^"]*)"$/) do |path|
  visit path
end

Then(/^I am an? "([^"]*)" user$/) do |user|
  page.driver.basic_authorize(*credentials_for_user(user))
end

Then(/^I can find content header "([^"]*)"$/) do |header|
  assert_equal header, find('#eso-content > div > h1').text
end

def credentials_for_user(user)
  # TODO: Modify deployment to add these users
  case user
  when 'devel'    then ['sthaha@redhat.com', 'redhat']
  when 'async'    then ['wlin@redhat.com', 'redhat']
  when 'qe'       then ['gbai@redhat.com', 'redhat']
  when 'secalert' then ['vdanen@redhat.com', 'redhat']
  when 'admin'    then ['admin@redhat.com', 'redhat']
  else raise 'Unknown user: #{user}'
  end
end
