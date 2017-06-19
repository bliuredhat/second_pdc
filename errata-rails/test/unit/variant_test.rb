require 'test_helper'

class VariantTest < ActiveSupport::TestCase
  test 'basic creation' do
    pv = ProductVersion.find_by_name 'RHEL-6'
    rv = Variant.find_by_name '6Server'
    v = Variant.new(:product_version => pv,
                    :rhel_variant => rv,
                    :name => 'foo',
                    :description => 'bar',
                    :tps_stream => 'a-test-machine')
    # Did not set the product explicitly
    assert v.product.nil?
    refute v.valid?
    # product set off product version before validation
    refute v.product.nil?

    # sub variant should not set tps stream
    assert v.errors.full_messages.include?("Tps stream is not allow to set for sub variant.")
    # variant name format is incorrect
    assert_errors_include(v, 'Rhel variant foo does not start with 6Server')
    v.name = '6Server-foo'

    v.tps_stream = nil
    v.product = nil
    assert v.valid?
    refute v.product.nil?

    #
    # At least name and rhel_variant need to be filled out.
    # Bug: 989469
    #
    v = Variant.new(:product_version => pv)
    refute v.valid?
  end

  test 'validate rhel release' do
    pv = ProductVersion.find_by_name 'RHEL-6'
    rv = Variant.find_by_name '6Server'
    v = Variant.new(:product_version => pv,
                    :product => pv.product,
                    :rhel_variant => rv,
                    :name => '6Server-foo',
                    :description => 'bar')
    assert v.valid?

    bad = RhelRelease.find(1)
    v.rhel_release = bad
    refute v.valid?
    assert_errors_include(v,
                          "Rhel release Product Version is #{pv.rhel_release.name}, and variant is #{bad.name}")
  end

  test 'get tps stream by variant' do
    variant_to_tps_stream_maps ={
      '6Server' => 'RHEL-6-Main-Server',
      '5Server-5.3.LL' => 'RHEL-5.3-LL-Server',
      '5Server-MRG-Messaging-1.0' => 'RHEL-5-Main-Server',
      # Sub-variants use RHEL variant TPS stream.
      '6Server-optional' => 'RHEL-6-Main-Server',
      '7Server-ResilientStorage' => 'RHEL-7-Main-Server',
      # EUS variants always use Z-stream TPS stream.
      '5Server-5.6.EUS' =>'RHEL-5.6-Z-Server',
      # Use main stream TPS stream if Z-stream TPS stream not exist.
      '6Client-optional-6.1.z' => 'RHEL-6-Main-Client',
      '6Workstation-6.6.z' => 'RHEL-6-Main-Workstation',
      # Z-stream TPS streams exist
      '7Server-7.1.Z-Server' => 'RHEL-7.1-Z-Server',
      # Support special variant format
      '7Server-LE-7.1.Z' => 'RHEL-7.1-Z-Server',
      '7Server-SA-7.1.Z' => 'RHEL-7.1-Z-Server',
      '7Server-Supplementary-LE-7.1.Z-Server' => 'RHEL-7.1-Z-Server',
    }

    variant_to_tps_stream_maps.each_pair do |v,t|
      rv = Variant.find_by_name v
      # Set tps_stream to nil so that ET can recalculate it.
      rv.update_attributes!(:tps_stream => nil)
      assert_equal t, rv.get_tps_stream
    end
    # This old variant didn't support TPS and should return nil without error
    tps_stream, errors = Variant.find_by_name("2.1AS").determine_tps_stream
    assert_nil tps_stream
    assert errors.empty?
  end

  test "set invalid TPS stream" do
    variant = Variant.find_by_name("7Server")
    [ ["some_tps_stream", "Tps stream 'some_tps_stream' is invalid"],
      ["RHEL-7-AA-ComputeNode", "Tps stream type 'AA' does not exist in TPS Server"],
      ["RHEL-7-Main-BB", "Tps stream variant 'BB' does not exist in TPS Server"],
    ].each do |tps_stream, expected_message|
      error = assert_raises(ActiveRecord::RecordInvalid) do
        variant.update_attributes!(:tps_stream => tps_stream)
      end
      assert_match(/#{expected_message}/, error.message)
    end
  end

  test "warn user if TPS stream not exist or inactive in TPS server" do
    variant = Variant.find_by_name("7Server")
    [ ["RHEL-99-Main-Server", "'RHEL-99-Main-Server' not found in TPS Server. Hence no stable systems to run TPS tests."],
      ["RHEL-5.3-Z-Server", "'RHEL-5.3-Z-Server' is disabled in TPS Server."]
    ].each do |tps_stream, expected_message|
      assert_nothing_raised do
        variant.update_attributes!(:tps_stream => tps_stream)
        assert_equal 0, variant.get_tps_stream_errors[:fatal].size, "Should not have fatal errors."
        assert_equal expected_message, variant.get_tps_stream_errors[:warn].map(&:message).join
      end
    end
  end

  test "live_variants_with_cpe method" do
    # Keep the result stable when more errata with CPEs are added to
    # fixtures
    Errata.with_scope(:find => {:conditions => 'errata_main.id < 19435'}) do
      Variant.live_variants_with_cpe.tap do |variants|
        assert_equal 47, variants.count, "(maybe fixture change?)"
        assert_equal "f4c957b0f278440a0d933e494bb713bd", Digest::MD5.hexdigest(variants.map(&:id).sort.join(",")), "(maybe fixture change?)"
      end
    end
  end
end
