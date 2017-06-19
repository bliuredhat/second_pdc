#
# See ./lib/finger_user.rb
#
require 'test_helper'

class FingerUserTest < ActiveSupport::TestCase

  test "returns expected hash when user exists" do
    login_name, realname = 'dmcpants', 'Dude McPants'
    stub_finger_command(login_name, realname)
    expected = { :login_name => "#{login_name}@redhat.com", :realname => realname }
    assert_equal expected, FingerUser.new(login_name).name_hash
  end

  test "returns nil when user does not exist" do
    stub_finger_command(nil)
    assert_nil FingerUser.new('bogus').name_hash
  end

  test "login name canonicalization" do
    ["foo", "foo@redhat.com", " Foo@REdHAT.com "].each do |login_name|
      assert_equal "foo", FingerUser.new(login_name).stripped_username
    end
  end

  def stub_finger_command(login_name=nil, realname=nil)
    finger_output = if login_name
      # To see how it should look:
      #  ruby -e 'puts `finger -m sbaird 2> /dev/null | head -1`.inspect'
      "Login: #{login_name}         \t\t\tName: #{realname}\n"
    else
      #  ruby -e 'puts `finger -m bogus 2> /dev/null | head -1`.inspect'
      ""
    end
    FingerUser.any_instance.stubs(:finger_command).returns(finger_output)
  end

end
