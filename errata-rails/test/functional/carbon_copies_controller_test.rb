require 'test_helper'

class CarbonCopiesControllerTest < ActionController::TestCase
  test 'add to cc list' do
    auth_as devel_user
    errata_id = 10140

    post :add_to_cc_list, :id => errata_id, :email => 'partner-testing@redhat.com'
    assert_equal "displayFlashNotice('error','User is not enabled: partner-testing@redhat.com.', true);", response.body

    post :add_to_cc_list, :id => errata_id, :email => 'dilbert@foo.com'
    assert_equal "displayFlashNotice('error','Could not find user dilbert@foo.com.', true);", response.body

    post :add_to_cc_list, :id => errata_id, :email => 'ckannan@redhat.com'
    assert_equal "displayFlashNotice('error','User already added to cc list.', true);$('#email').val('');", response.body

    user = User.find_by_login_name! 'jorris@redhat.com'
    refute CarbonCopy.exists? :errata_id => errata_id, :who_id => user.id
    post :add_to_cc_list, :id => errata_id, :email => user.login_name
    assert_response :success
    assert CarbonCopy.exists? :errata_id => errata_id, :who_id => user.id
  end

  test 'remove from cc list' do
    auth_as devel_user
    errata_id = 10140
    user_id = 268050

    assert CarbonCopy.exists? :errata_id => errata_id, :who_id => user_id
    post :remove_from_cc_list, :id => 10140, :user_id => user_id
    assert_response :success
    refute CarbonCopy.exists? :errata_id => errata_id, :who_id => user_id
  end
end
