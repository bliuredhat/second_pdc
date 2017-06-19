require 'test_helper'

class MultiProductChannelMapTest < ActiveSupport::TestCase
  test "constraints" do
    pkg = Package.find_by_name 'sblim'
    opt_channel = Channel.find_by_name 'rhel-x86_64-server-optional-6'
    rhel_channel = Channel.find_by_name 'rhel-x86_64-server-6'
    destination_channel = Channel.find_by_name 'rhel-x86_64-rhev-mgmt-agent-6'

    map = MultiProductChannelMap.new(:package => pkg,
                                     :origin_channel => rhel_channel,
                                     :origin_product_version_id => rhel_channel.product_version.id,
                                     :destination_product_version_id => rhel_channel.product_version.id,
                                     :destination_channel => rhel_channel)
    assert !map.valid?
    assert !map.errors.has_key?(:package)
    assert map.errors.has_key?(:destination_product_version)
    assert map.errors.full_messages.include?('Destination product version RHEL or RHEL Optional is _not_ allowed as a destination')

    bad_key_channel = Channel.find_by_name 'rhel-x86_64-rhev-v2v-5'
    map = MultiProductChannelMap.new(:package => pkg,
                                     :origin_product_version_id => opt_channel.product_version.id,
                                     :destination_product_version_id => bad_key_channel.product_version.id,
                                     :origin_channel => opt_channel,
                                     :destination_channel => bad_key_channel)
    assert !map.valid?
    assert map.errors.full_messages.include?('Origin product version Signing keys must match between product versions. RHEL-6 has signing key redhatrelease2; whereas RHEL-5-RHEV has key redhatrelease.'), map.errors.full_messages.inspect

    map = MultiProductChannelMap.new(:package => pkg,
                                     :origin_product_version_id => opt_channel.product_version.id,
                                     :destination_product_version_id => destination_channel.product_version.id,
                                     :origin_channel => opt_channel,
                                     :destination_channel => destination_channel)
    assert map.valid?, map.errors.full_messages.join(", ")
  end

  test "channel search" do
    # pretend all multi-product mappings are valid
    Push::Dist.stubs(:should_use_multi_product_mapping? => true)

    e = Errata.find 11129
    assert_equal 1, e.packages.length
    pkg = e.packages.first
    assert_equal 'krb5', pkg.name

    destination_channel = Channel.find_by_name 'rhel-x86_64-rhev-mgmt-agent-6'
    opt_channel = Channel.find_by_name 'rhel-x86_64-client-optional-6'

    channels_before_destination = Push::Rhn.channels_for_errata(e)
    assert channels_before_destination.include?(opt_channel), channels_before_destination.map(&:name).join(',')
    assert !channels_before_destination.include?(destination_channel), channels_before_destination.map(&:name).join(',')

    map = MultiProductChannelMap.create!(:package => pkg,
                                         :origin_product_version_id => opt_channel.product_version.id,
                                         :destination_product_version_id => destination_channel.product_version.id,
                                         :origin_channel => opt_channel,
                                         :destination_channel => destination_channel)
    channels_after_destination = Push::Rhn.channels_for_errata(e)
    # Should still include optional channel
    assert channels_after_destination.include?(opt_channel), channels_before_destination.map(&:name).join(',')
    # Should now include destination channel
    assert channels_after_destination.include?(destination_channel), channels_before_destination.map(&:name).join(',')
    # Should _only_ include the one new destination channel
    assert_equal (channels_before_destination.length + 1), channels_after_destination.length
    channels_after_destination.delete(destination_channel)
    assert_equal channels_before_destination, channels_after_destination
  end

  test 'mapped channel respects product listings' do
    # This advisory is a copy of a jasper advisory which caused a problem
    # when multi-product mappings were used.
    #
    # Certain subpackages and arches were shipped to mapped channels
    # even though they weren't in composedb (product listings).
    # See RT 329806.
    hash = Push::Rhn.make_hash_for_push(Errata.find(19435), releng_user.login_name)
    file_to_channel = hash['errata_files'].map do |x|
      file = File.basename(x['ftppath'])
      x['rhn_channel'].map{|ch| "#{file} => #{ch}"}
    end
    file_to_channel = file_to_channel.flatten.sort
    assert_testdata_equal 'file_channel_map_19435.txt', file_to_channel.join("\n")
  end
end
