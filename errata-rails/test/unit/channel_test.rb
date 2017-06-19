require 'test_helper'

class ChannelTest < ActiveSupport::TestCase

  setup do
    @channel_classes = [BetaChannel, EusChannel, FastTrackChannel, LongLifeChannel, PrimaryChannel]
    @channel_types = @channel_classes.map(&:to_s)
  end

  test "sub channels" do
    expected = @channel_types.to_set
    Channel.channel_types.each { |t| assert expected.include?(t) }
    assert_equal expected.length, Channel.channel_types.length
  end

  test "is parent" do
    rhel_variant = Variant.find_by_name("6Server")
    parent_channel = Channel.where('variant_id = ?', rhel_variant).first
    assert parent_channel.is_parent?

    child_channel = Channel.where('name like ?', '%-optional%').first
    refute child_channel.is_parent?
  end

  test "get parent channel" do
    channel_maps = {
      'rhel-i386-server-optional-6' => 'rhel-i386-server-6',
      'rhel-ppc64-server-optional-6' => 'rhel-ppc64-server-6',
      'rhel-ppc64-server-6' => 'rhel-ppc64-server-6',
    }

    channel_maps.each_pair do |c,p|
      parent = Channel.find_by_name(c).get_parent;
      assert !parent.nil?
      assert_equal p, parent.name
    end
  end

  test "returns channel model name on all channel types" do
    assert_equal ["Channel"], @channel_classes.map { |c| c.model_name }.uniq
  end

end
