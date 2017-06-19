require 'test_helper'

class Api::V1::UserControllerTest < ActionController::TestCase
  setup do
    @zoro_login_name = "zoro@redhat.com"
    @zoro_realname = "Zoro San"
    @engineering = UserOrganization.find_by_name('Engineering')
  end

  test "create a user account" do
    auth_as admin_user

    # stubs finger to make the user a real person.
    FingerUser.any_instance.stubs(:name_hash).returns({:login_name => @zoro_login_name, :realname => @zoro_realname})

    # user not yet exists
    user = User.find_by_login_name(@zoro_login_name)
    assert_nil user

    userinfo = {
      :login_name => @zoro_login_name,
      :realname   => "A test user",
      :user_organization_id => @engineering.id,
      :roles => %w[readonly secalert],
      :email_address => "zoro_email@redhat.com"
    }

    assert_difference("User.count", 1) do
      post :create, userinfo.merge({:format => :json})
    end

    assert_testdata_equal 'api/v1/user/create.json', formatted_json_response
  end

  test "create a user without specifying roles" do
    auth_as admin_user

    # stubs finger to make the user a real person.
    FingerUser.any_instance.stubs(:name_hash).returns({:login_name => @zoro_login_name, :realname => @zoro_realname})

    # user not yet exists
    user = User.find_by_login_name(@zoro_login_name)
    assert_nil user

    userinfo = {
      :login_name => @zoro_login_name,
      :format     => :json
    }

    assert_difference("User.count", 1) do
      post :create, userinfo
    end

    assert_response :created

    # user should have errata role by default
    assert_array_equal ['errata'], User.last.roles.map(&:name)
  end

  test "create a user account with bad params" do
    auth_as admin_user

    post :create, {:format => :json}

    assert_testdata_equal 'api/v1/user/create_with_bad_params.json', formatted_json_response
  end

  test "find a user" do
    auth_as admin_user
    user = User.find(4)

    post :show, {:id => user.login_name, :format => :json}

    assert_testdata_equal 'api/v1/user/find_by_login_name.json', formatted_json_response
  end

  test "find invalid user" do
    auth_as admin_user

    [
      ["onepiece/blahblah.redhat.com", "find_invalid_user_by_login_name.json"],
      ["99999", "find_invalid_user_by_id.json"]
    ].each do |params|
      get :show, {:id => params[0], :format => :json}
      assert_testdata_equal "api/v1/user/#{params[1]}", formatted_json_response
    end
  end

  test "update user" do
    auth_as admin_user

    user = User.find(4)
    user_group = UserOrganization.find_by_name!('RHEV Hypervisor & Cluster')
    assert user.enabled?, "fixture error."
    assert user.receives_mail?, "fixture error."
    assert user_group != user.organization, "fixture error."
    assert_array_equal ['errata', 'devel'], user.roles.map(&:name), "fixture error."

    userinfo = {
      :id => user.login_name,
      :enabled => false,
      :receives_mail => false,
      :organization => user_group.name,
      :email_address => "",
      :roles => ['pm', 'releng'],
      :format => :json
    }

    put :update, userinfo

    assert_testdata_equal 'api/v1/user/update.json', formatted_json_response
    user.reload
    # when email_address is empty, login_name is used as an email
    assert_equal user.login_name, user.email
  end

  test "update user with bad data" do
    auth_as admin_user

    user = User.find(4)
    [
      [{:roles => ['pm', 'releng', 'onepiece', 'naruto']}, "update_with_bad_roles.json"],
      [{:organization => 'Umbrella Corporation'}, "update_with_bad_organization_name.json"]
    ].each do |data|
      userinfo = {
        :id => user.login_name,
        :format => :json
      }

      put :update, userinfo.merge(data[0])

      assert_testdata_equal "api/v1/user/#{data[1]}", formatted_json_response
    end
  end

  # Bug 1168560 - Roles should not be erased to default if updating user's the other parameters
  test "update user details other than roles should not reset roles" do
    auth_as admin_user

    expected_roles = ['errata', 'devel', 'qa', 'pm']
    user = User.find(4)
    user.roles = Role.where(:name => expected_roles)
    user.save!

    userinfo = {
      :id => user.login_name,
      :organization => UserOrganization.last.name,
      :format => :json
    }
    put :update, userinfo
    assert_response :ok

    user.reload

    assert_array_equal expected_roles, user.roles.map(&:name)
  end

  test "roles parameter is not array" do
    auth_as admin_user

    user = User.find(4)
    userinfo = {
      :id => user.login_name,
      :roles => 'devel',
      :format => :json
    }
    put :update, userinfo

    assert_testdata_equal "api/v1/user/roles_parameter_not_array.json", formatted_json_response
  end

  # Bug 1168567 - missing validation for boolean field
  test "enabled parameter not a boolean" do
    auth_as admin_user

    user = User.find(4)
    userinfo = {
      :id => user.login_name,
      :enabled => "a string",
      :format => :json
    }
    put :update, userinfo

    assert_testdata_equal "api/v1/user/enabled_parameter_not_boolean.json", formatted_json_response
  end
end
