require 'test_helper'

class PdcAdvisoryTest < ActionDispatch::IntegrationTest

  setup do
    auth_as devel_user
  end

  test 'pdc manual create selection is shown' do
    # going to new advisory should show pdc manual create
    visit advisory_new_path
    pdc_manual_create = 'PDC Manual Create'

    assert page.has_content? pdc_manual_create

    # one of the headers should be 'PDC Manaul Create'
    choices = find_all('#new_choose label > h3')
    choices_text = choices.map(&:text)
    assert choices_text.include?(pdc_manual_create),
           "#{pdc_manual_create} option not found in #{choices_text.join(',')}"
  end

end
