Given(/^I cannot see "([^"]*)" selection$/) do |content|
  within_sidebar do
    assert page.has_no_content?(content)
  end
end

When(/^I choose the Advisory Type: "([^"]*)"$/) do |value|
  within_sidebar do
    choose value
  end
end

Then(/^I can see "([^"]*)" selection$/) do |content|
  within_sidebar do
    assert page.has_content?(content)
  end
end

When(/^I select the "([^"]*)": "([^"]*)"$/) do |selection, value|
  within_sidebar do
    select value, from: id_for_label(selection)
  end
end

Then(/^"([^"]*)" selection changes to "([^"]*)"$/) do |selection, expected_value|
  within_sidebar do
    assert page.has_select?(id_for_label(selection), selected: expected_value)
  end
end

# NOTE: Works arounds the lack of 'for' attributes in <label>.
# TODO: Fix the UI so that <label for="element_id"> is used instead
# of bare <label>
def id_for_label(label)
  return label if label.ends_with?('_id')
  (label + '_id').underscore
end

def within_sidebar
  within(:xpath, '//*[@id="eso-content"]/div[1]/form/div[2]/div[1]') do
    yield
  end
end
