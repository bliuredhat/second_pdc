require 'test_helper'

class UserTest < ActiveSupport::TestCase
  def setup
    @test_user = User.create(
      :login_name => 'tmctest@redhat.com',
      :realname => 'Testy McTest',
      :roles => Role.where(:name=>'errata')
    )
  end

  test "add role and remove role methods" do
    assert @test_user.in_role?('errata')
    assert_equal 1, @test_user.roles.length

    # Add a role
    refute @test_user.in_role?('devel')
    @test_user.add_role('devel')
    assert_equal 2, @test_user.roles.length
    assert @test_user.in_role?('devel')

    # Don't add dupes
    @test_user.add_role('devel')
    assert_equal 2, @test_user.roles.length
    assert @test_user.in_role?('devel')

    # Remove role
    @test_user.remove_role('devel')
    assert_equal 1, @test_user.roles.length
    refute @test_user.in_role?('devel')

    # Remove role that's not there
    @test_user.remove_role('devel')
    assert_equal 1, @test_user.roles.length
    refute @test_user.in_role?('devel')

    # Replace all roles
    @test_user.replace_roles('errata', 'qa', 'pm')
    assert_equal 3, @test_user.roles.length
    assert @test_user.in_role?('qa')
    assert @test_user.in_role?('pm')
  end

  test "permitted method" do
    # Just test a couple of examples..

    refute @test_user.can_request_signatures?
    refute @test_user.permitted?(:request_signatures)
    @test_user.add_role('qa')
    assert @test_user.can_request_signatures?
    assert @test_user.permitted?(:request_signatures)

    refute @test_user.can_reschedule_covscan?
    refute @test_user.permitted?(:reschedule_covscan)
    @test_user.add_role('covscan-admin')
    assert @test_user.can_reschedule_covscan?
    assert @test_user.permitted?(:reschedule_covscan)
  end

  test "permissions based on UserPermissions::ROLE_PERMISSIONS" do
    refute @test_user.can_see_add_released_packages_tab?
    refute @test_user.permitted?(:see_add_released_packages_tab)
    @test_user.add_role('releng')
    assert @test_user.can_see_add_released_packages_tab?
    assert @test_user.permitted?(:see_add_released_packages_tab)
  end

  test "no role is treated as readonly" do
    @test_user.replace_roles('errata')
    assert @test_user.has_no_role?
    assert @test_user.is_readonly?
    refute @test_user.can_see_embargoed?

    @test_user.replace_roles('errata', 'devel')
    refute @test_user.has_no_role?
    refute @test_user.is_readonly?
    assert @test_user.can_see_embargoed?

    @test_user.replace_roles('errata', 'devel', 'readonly')
    refute @test_user.has_no_role?
    assert @test_user.is_readonly?
    refute @test_user.can_see_embargoed?
  end

  test "create new user without mandatory values should fail" do
    error = assert_raise(ActiveRecord::RecordInvalid) do
      User.create!(:roles => Role.last(2))
    end
    assert_equal "Validation failed: Login name can't be blank, Realname can't be blank", error.message
  end

  test "creating duplicate user should fail" do
    user = User.last
    error = assert_raise(ActiveRecord::RecordInvalid) do
      User.create!(
        :login_name => user.login_name,
        :realname => user.realname,
        :roles => Role.last(2))
    end
    assert_equal "Validation failed: Login name has already been taken", error.message
  end
end
