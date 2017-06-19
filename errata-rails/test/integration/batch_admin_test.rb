require 'test_helper'

class BatchAdminTest < ActionDispatch::IntegrationTest

  test "create new batch" do
    auth_as admin_user

    visit '/batches'
    click_on 'New Batch'
    fill_in 'batch[name]', :with => 'test_batch_1'

    assert_difference('Batch.count', 1) do
      click_button 'Create'
    end

    assert page.find('#flash_notice').has_content?('Batch was successfully created')
  end

  test "create new batch with duplicate name" do
    auth_as admin_user

    existing_batch = Batch.first

    visit '/batches'
    click_on 'New Batch'
    fill_in 'batch[name]', :with => existing_batch.name

    assert_no_difference('Batch.count') do
      click_button 'Create'
    end

    assert has_text?('Name has already been taken')
  end

  test "released batch cannot be edited" do
    auth_as admin_user

    batch = Batch.released.first
    assert batch.is_released?

    visit "/batches/#{batch.id}"

    assert has_text?('This batch has been released')
    assert has_no_button? 'Edit'

    visit "/batches/#{batch.id}/edit"
    assert page.find('#flash_alert').has_content?('Batch cannot be edited')
  end
end
