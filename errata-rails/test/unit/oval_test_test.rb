require 'test_helper'

class OvalTestTest < ActiveSupport::TestCase
  def setup
    # Pick an RHSA (from fixture data) we can use. Note:
    # - OvalTest.new will throw errors if there's no builds
    # - If there's no variants then the cpe_list will be empty
    @rhsa = RHSA.shipped_live.select { |rhsa| rhsa.build_mappings.any? && rhsa.variants.any? }.last

    # Create an OvalTest from the RHSA
    @oval_test = OvalTest.new(@rhsa)
  end

  test 'oval xmlrpc should be disabled by default' do
    refute Push.oval_conf.xmlrpc_enabled
  end

  test "cpe list looks correct" do
    assert @oval_test.cpe_list,            "cpe list should exist"
    assert @oval_test.cpe_list.length > 0, "cpe list should not be empty"
    assert @oval_test.cpe_list.is_a?(Set), "cpe list should be a set"

    @oval_test.cpe_list.to_a.each do |cpe_for_oval|
      # Just test it's the right size, (not currently testing the content)
      # (Used to be 4 instead of 5, see Bug 973644)
      assert_equal 5, cpe_for_oval.split(':').length, "cpe text has unexpected field count"
    end
  end

  test "no error when builds empty" do
    advisory = RHSA.shipped_live.select{ |rhsa| rhsa.build_mappings.empty?}.last
    assert OvalTest.new(advisory).criteria.empty?
  end
end
