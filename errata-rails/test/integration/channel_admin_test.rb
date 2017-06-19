require 'test_helper'

class ChannelAdminTest < ActionDispatch::IntegrationTest

  setup do
    @channel = Channel.find_by_name('rhel-x86_64-server-rhsclient-6')
    @title = 'Test Channel'
  end

  test "create channel" do
    auth_as admin_user

    pversion_id = @channel.product_version.id

    [:LongLifeChannel, :EusChannel, :FastTrackChannel, :PrimaryChannel].each_with_index do |channel_type, i|
      visit "/product_versions/#{pversion_id}/channels/new"

      # Don't allow creating channels without a name, see Bug 989864
      click_button 'Create'
      assert page.has_content? 'error prohibited'

      full_title = "#{@title} #{i}"
      assert_difference('Channel.count') {
        fill_in('channel_name', :with => full_title)
        select(channel_type, :from => 'channel_type')
        click_button 'Create'
      }

      assert page.has_content? "RHN channel '#{full_title}' was successfully created."
      assert find(:xpath, "//span[@class='short-name']").has_content?(full_title)
    end
  end

  test "edit channel" do
    auth_as admin_user

    pversion_id = @channel.product_version.id
    visit "/product_versions/#{pversion_id}/channels/#{@channel.id}/edit"
    fill_in('channel_name', :with => @title)
    click_button 'Update'

    assert page.has_content? "RHN channel '#{@title}' was successfully updated."
    assert find(:xpath, "//span[@class='short-name']").has_content?(@title)
    assert @title, @channel.reload.name
  end

  test "attempt to create duplicate channel should fail" do
    auth_as admin_user

    pversion_id = @channel.product_version.id
    cname = ProductVersion.find(227).channels.first.name
    channel_path = "/product_versions/#{pversion_id}/channels"

    assert_no_difference('Channel.count') do
      visit "#{channel_path}/new"
      fill_in('channel_name', :with => cname)
      select(:PrimaryChannel, :from => 'channel_type')
      click_button 'Create'
    end

    assert page.has_content?("Name has already been taken")
    assert_equal channel_path, current_path
  end

end
