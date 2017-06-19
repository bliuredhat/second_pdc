When(/^I select "([^"]*)" link$/) do |link|
  click_link link
end

Then(/^I should see the following in title:$/) do |title|
  within first('.item-title') do
    title.rows.flatten.each do |content|
      assert has_content? content
    end
  end
end

Then(/^I should see details about variant "([^"]*)":$/) do |variant_name|
  variant = Variant.find_by_name(variant_name)

  assert find(:xpath, "//span[@class='object-type']").has_content?('[Variant]')
  assert find(:xpath, "//span[@class='short-name']").has_content?(variant.name)
  assert find(:xpath, "//span[@class='long-name']").has_content?(variant.description)
end
