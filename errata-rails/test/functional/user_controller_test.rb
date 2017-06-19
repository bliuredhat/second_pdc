require 'test_helper'

class UserControllerTest < ActionController::TestCase
  # Bug 1120538
  test 'cannot remove errata role by edit' do
    auth_as admin_user

    user = User.find(4)
    assert_equal %w[devel errata], user.roles.map(&:name).sort

    post(:edit,
      :id => user.id,
      :user => { :roles => %w[readonly secalert] })
    assert_response :ok, response.body

    # It should have set the roles I requested, but should not have
    # removed 'errata' role
    assert_equal %w[errata readonly secalert], user.reload.roles.map(&:name).sort
  end

  [:edit, :update].each do |action|
    test "update existing user account by #{action} action" do
      auth_as admin_user

      user = User.find(4)

      user_group = UserOrganization.find_by_name!('RHEV Hypervisor & Cluster')
      assert user.enabled?, "fixture error."
      assert user.receives_mail?, "fixture error."
      assert user_group != user.organization, "fixture error."
      assert user.email_address.blank?, "fixture error."
      user4_email = "user4_email@redhat.com"

      userinfo = {
        :enabled => false,
        :receives_mail => false,
        :user_organization_id => user_group.id,
        :email_address => user4_email
      }

      post action, :id => user.id, :user => userinfo, :format => :js

      assert_response :ok, response.body
      [
        Regexp.escape("Enabled changed from 'true' to 'false'"),
        Regexp.escape("Organization changed from 'IE - Linux Engineering' to 'RHEV Hypervisor<br/>  & Cluster'<br/>"),
        Regexp.escape("The role 'Devel' was removed"),
        Regexp.escape("Receives mail changed from 'true' to 'false'"),
        Regexp.escape("The user #{user.realname} (#{user.login_name}) with a separate email<br/>#{user4_email} is currently DISABLED and has role 'Errata'"),
        Regexp.escape("Email address '#{user4_email}' was added"),
      ].each do |message|
        assert_match(/#{message}/, response.body)
      end

      user.reload

      # user is now disabled
      refute user.enabled?
      # user no longer receive email notification
      refute user.receives_mail?
      # user group is also updated
      assert_equal user_group, user.organization
    end
  end

  test "update with bad data" do
    auth_as admin_user

    user = User.find(4)
    userinfo = {:user_organization_id => 999999}

    post :update, :id => user.id, :user => userinfo, :format => :js
    message = "Couldn&#x27;t find UserOrganization with id=999999"
    assert_match(/#{message}/, response.body)
  end

  test "update with no user data" do
    auth_as admin_user
    user = User.find(4)

    post :update, :id => user.id, :format => :js
    message = "No user data is provided"
    assert_match(/#{message}/, response.body)
  end

  [:add_user, :create].each do |action|
    test "create a new user account by #{action} action" do
      auth_as admin_user

      login_name = "zoro@redhat.com"
      realname = "Zoro San"
      user_group = UserOrganization.find_by_name('Engineering')
      # stubs finger to make the user a real person.
      FingerUser.any_instance.stubs(:name_hash).returns({:login_name => login_name, :realname => realname})

      # user not yet exists
      user = User.find_by_login_name(login_name)
      assert_nil user

      userinfo = {
        :login_name => login_name,
        :user_organization_id => user_group.id,
        :roles => %w[readonly secalert]
      }

      assert_difference("User.count", 1) do
        post action, :user => userinfo, :format => :js
      end
      assert_response :ok, response.body

      assert_match(/#{Regexp.escape("User #{realname} &lt; #{login_name} &gt; account has been created successfully.")}/, response.body)

      new_user = User.last

      assert_equal login_name, new_user.login_name
      assert_equal realname, new_user.realname
      # login_name is used as an email if email_address is not specified
      assert_blank new_user.email_address
      assert_equal login_name, new_user.email

      [:receives_mail?, :enabled?].each do |key|
        assert new_user.send(key)
      end

      assert_equal user_group.name, new_user.send(:organization_name)
      # should always add 'errata' role by default
      assert_array_equal userinfo[:roles].concat(['errata']), new_user.send(:roles).map(&:name)
    end
  end

  test "real user cannot change login name and realname" do
    auth_as admin_user

    user = User.find(4)
    orig_user = user.dup
    # stubs finger to make the user a real person.
    user_info = {:login_name => user.login_name, :realname => user.realname}
    FingerUser.any_instance.stubs(:name_hash).returns(user_info)

    userinfo = {
     :login_name => "onepiece@redhat.com",
     :realname   => "One Piece",
     :roles => user.roles.map(&:name)
    }
    post :update, :id => user.login_name, :user => userinfo, :format => :js

    assert_response :ok, response.body
    assert_match(/No changes/, response.body)

    user.reload

    # all values should remain the same
    [:login_name, :realname].each do |key|
      assert_equal orig_user.send(key), user.send(key)
    end
  end

  test "special user only can set receives_mail when email_address is given " do
    auth_as admin_user

    special_user = User.find_by_login_name!("host/compose.app.eng.rdu.redhat.com@REDHAT.COM")
    assert_blank special_user.email_address

    # email_address is not given
    userinfo = { :receives_mail => true, :roles => ['errata'] }
    post :update, :id => special_user.login_name, :user => userinfo, :format => :js

    assert_response :ok, response.body
    # receives_mail should not be changed
    assert_match(/No changes/, response.body)

    special_user.reload
    refute special_user.receives_mail?

    special_email = 'special_user@redhat.com'
    # email_address is given
    userinfo = { :receives_mail => true, :email_address => special_email }
    post :update, :id => special_user.login_name, :user => userinfo, :format => :js

    assert_response :ok, response.body
    # receives_mail is changed for special user
    [
      Regexp.escape("Receives mail changed from 'false' to 'true'"),
      Regexp.escape("Email address '#{special_email}' was added"),
    ].each do |message|
      assert_match(/#{message}/, response.body)
    end
  end

  test "show user by login name" do
    auth_as admin_user

    user_1 = User.find_by_login_name!("host/compose.app.eng.rdu.redhat.com@REDHAT.COM")
    user_2 = User.find(4)

    [user_1, user_2].each do |user|
      get :show, :id => user.login_name
      assert_response :ok, response.body
      title = Regexp.escape("Edit #{user.realname} (#{user.login_name})")
      assert_match(/title/, response.body)
    end
  end

  test "find user redirect to create user page if a real person has no errata account" do
    auth_as admin_user

    login_name = "zoro@redhat.com"
    realname = "Zoro San"
    # stubs finger to make the user a real person.
    FingerUser.any_instance.stubs(:name_hash).returns({:login_name => login_name, :realname => realname})

    post :find_user, :id => login_name

    message = Regexp.escape(
      "#{realname} &lt; #{login_name} &gt; does not currently have an account " +\
      "in Errata Tool. Do you want to create an account for this user?")
    assert_match(/#{message}/, flash[:alert])
    assert_response :redirect, response.body
  end

  test "find invalid user" do
    auth_as admin_user

    login_name = "one piece"
    # stubs finger to make the user a real person.
    FingerUser.any_instance.stubs(:name_hash).returns(nil)

    post :find_user, :id => login_name

    assert_match(/No such user #{login_name}/, flash[:error])
    assert_response :redirect, response.body
  end

  test "find user without params" do
    auth_as admin_user

    post :find_user, {}

    assert_response :not_found, response.body
    assert_match(/No user provided/, response.body)
  end

  test "find a valid user" do
    auth_as admin_user

    user_1 = User.find_by_login_name!("host/compose.app.eng.rdu.redhat.com@REDHAT.COM")
    user_2 = User.find(4)

    [user_1, user_2].each do |user|
      post :find_user, :id => user.login_name
      assert_redirected_to :action => :show, :id => user
    end
  end

  test "creating a user that already exists should fail" do
    auth_as admin_user

    user = User.find(4)
    get :new, :login_name => user.login_name, :format => :js

    assert_response :ok, response.body
    message = Regexp.escape("User with #{user.login_name} already exists in Errata Tool")
    assert_match(/#{message}/, response.body)
  end

  test "new user page" do
    auth_as admin_user

    get :new, :format => :js
    assert_response :ok, response.body
  end
end
