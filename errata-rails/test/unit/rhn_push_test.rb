require 'test_helper'

class RhnPushTest < ActiveSupport::TestCase

  test "rpm channel map raises exception with mutual exclusive parameters" do
    error = assert_raises(RuntimeError) {
      Push::Rhn.rpm_channel_map(Errata.first, {:shadow => 1, :fast_track => 1})
    }
    assert_equal 'Fast track and shadow are mutually exclusive!', error.message
  end

  test "create rpm channel map includes MultiProductChannelMap" do
    rhba_async.update_attribute(:supports_multiple_product_destinations, 1)

    MultiProductChannelMap.expects(:mappings_for_package).at_least_once.returns([])
    Push::Rhn.rpm_channel_map(rhba_async) {}
  end

  test "rpm channel map with no channels" do
    result = []

    ChannelLink.with_scope(:find => ChannelLink.where('1 = 0')) do
      Push::Rhn.rpm_channel_map(rhba_async) {|*v| result << v}
    end
    assert_equal [], result
  end

  # https://bugzilla.redhat.com/show_bug.cgi?id=1445641
  test 'PDC Advisory without debuginfo rpms has correct channels' do
    errata = Errata.find 10000
    assert errata.is_pdc?

    map = {}
    VCR.use_cassettes_for(:pdc_ceph21) do
      map = Push::Rhn.ftp_files errata
    end

    files = map.collect {|m| m['ftppath']}
    assert files.none? {|f| f =~ /debuginfo/}, "There should be no debuginfo files: #{files.join(', ')}"
    assert_equal 3, files.length, files.join(',')

    channels = map.collect {|m| m['rhn_channel']}.flatten.uniq
    assert channels.none? {|c| c =~ /debuginfo/}, "There should be no debuginfo channels: #{channels.join(', ')}"
    assert_equal 2, channels.length, channels.join(',')
  end
end
