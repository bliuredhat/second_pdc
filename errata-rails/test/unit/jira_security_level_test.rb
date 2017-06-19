require 'test_helper'

class JiraSecurityLevelTest < ActiveSupport::TestCase
  setup do
    Settings.jira_security_level_effects = {
      'Private Level' => 'PRIVATE',
      'Public Level' => 'PUBLIC',
    }
  end

  test "defaults to secure" do
    level = JiraSecurityLevel.create(:name => 'some unknown level', :id_jira => 12345)
    assert_equal 'SECURE', level.effect
  end

  test "uses settings" do
    priv = JiraSecurityLevel.create(:name => 'Private Level', :id_jira => 12345)
    pub = JiraSecurityLevel.create(:name => 'Public Level', :id_jira => 12346)
    assert_equal 'PRIVATE', priv.effect
    assert_equal 'PUBLIC', pub.effect

    # settings ignored if passing in effect explicitly
    flip_priv = JiraSecurityLevel.create(:name => 'Private Level', :effect => 'PUBLIC', :id_jira => 12347)
    flip_pub = JiraSecurityLevel.create(:name => 'Public Level', :effect => 'PRIVATE', :id_jira => 12348)
    assert_equal 'PUBLIC', flip_priv.effect
    assert_equal 'PRIVATE', flip_pub.effect
  end

  test "can't use invalid effects" do
    level = JiraSecurityLevel.create(:name => 'My Level', :effect => 'frobnitz', :id_jira => 12345)
    refute level.valid?
  end

  test "from rpc" do
    level = JiraSecurityLevel.make_from_rpc({
      'id' => 1234, 'name' => 'Private Level'
    })
    assert_equal 'PRIVATE', level.effect
    assert_valid level
  end

  test "from rpc returns nil if called with nil" do
    level = JiraSecurityLevel.make_from_rpc(nil)
    assert_equal nil, level
  end
end
