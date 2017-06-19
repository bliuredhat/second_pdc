advisory = Transform(/[Aa]dvisory ["'](\d+|\w+-\d+:\d+(?:|-\d+)?)["']/) do |name_or_id|
  Errata.find_by_advisory(name_or_id)
end

Given(/^.*(#{advisory}) set to "(.+)" state$/) do |errata, state|
  errata.change_state!(state, @devel)
  @errata = errata
end

When(/I view details of (#{advisory})$/) do |adv|
  @advisory = adv
  visit "/advisory/#{adv.id}"
end

When(/I click on "([^"]*)" Tab$/) do |tab|
  within_tabbar { click_on tab }
end

Then(/^I can see "([^"]*)" Tab$/) do |tab|
  within_tabbar { assert has_link?(tab) }
end

def within_tabbar
  within('#eso-content div.eso-tab-bar') { yield }
end

def within_content
  within('#eso-content  div.eso-tab-content') { yield }
end

def within_popover
  popover = find('.popover-content')
  within(popover) { yield }

  # Click in popover to dismiss
  popover.click
end
