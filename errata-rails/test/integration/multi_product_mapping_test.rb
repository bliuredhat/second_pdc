require 'test_helper'

class MultiProductMappingTest < ActionDispatch::IntegrationTest

  setup do
    auth_as admin_user
  end

  test 'general CRUD' do
    visit '/multi_product_mappings'
    click_link "New Mapping"

    fill_in_mapping_fields ({:mapping_type => 'RHN channel',
                            :package => 'augeas',
                            :origin => 'rhel-i386-client-supplementary-5',
                            :destination => 'rhel-i386-server-hts-5'})
    assert_difference 'MultiProductChannelMap.count', 1 do
      click_button 'Create'
    end

    assert has_content? "Multi product mapping has been created."
    assert has_content? 'Summary'
    assert has_content? 'Subscribers'

    click_on 'Edit'

    fill_in_mapping_fields({:destination => 'rhel-i386-server-supplementary-5.3.ll'})
    click_button 'Update'

    assert has_content? 'Multi product mapping has been updated.'
    assert has_content? 'rhel-i386-server-supplementary-5.3.ll'
    assert_difference 'MultiProductChannelMap.count', -1 do
      click_on 'Delete'
    end
    assert has_link? 'New Mapping'
  end

  test 'messages appears when empty form is submitted' do
    visit '/multi_product_mappings/new'
    assert has_content? 'New Multi Product Channel Map'
    click_button 'Create'
    assert has_content? '4 errors prohibited this multi product channel map from being saved'
    ['Origin product version',
     'Destination product version',
     'Origin channel',
     'Destination channel'].each do |f|
      assert has_content? "#{f} can't be blank"
    end
  end

  test 'add / remove subscriber' do
    cdn_repo_map = MultiProductCdnRepoMap.last
    cdn_repo_map.subscribers.delete_all
    assert_equal 0, cdn_repo_map.reload.subscribers.count
    visit "/multi_product_mappings/#{cdn_repo_map.id}?mapping_type=#{cdn_repo_map.mapping_type}"
    assert has_content? 'Subscribers'
    assert has_no_text? devel_user.login_name
    fill_in 'subscriber_name', :with => devel_user.login_name
    assert_difference 'MultiProductCdnRepoMapSubscription.count', 1 do
      click_button 'Add a Subscriber'
    end

    # As we are unable to handle jquery's output, we need to reload the page
    # at this stage to verify the contents
    visit "/multi_product_mappings/#{cdn_repo_map.id}?mapping_type=#{cdn_repo_map.mapping_type}"
    assert has_text? devel_user.login_name
    assert_difference 'MultiProductCdnRepoMapSubscription.count', -1 do
      click_link 'Remove'
    end
    assert has_no_text? devel_user.login_name
  end

  def fill_in_mapping_fields(fields={})
    choose fields[:mapping_type] if fields[:mapping_type]
    fill_in 'Package', :with => fields[:package] if fields[:package]
    fill_in 'Origin Channel/Cdn Repo', :with => fields[:origin] if fields[:origin]
    fill_in 'Destination Channel/Cdn Repo', :with => fields[:destination] if fields[:destination]
  end
end
