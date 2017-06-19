require 'test_helper'

class PushTargetsWereTest < ActiveSupport::TestCase
  setup do
    @cdn = PushTarget.find_by_name("cdn")
    @variant_7Server = Variant.find_by_name("7Server")
  end

  test "set push target" do
    pr = PackageRestriction.first
    original_push_targets = pr.push_targets.to_a
    new_push_targets = [@cdn]
    ActiveRecord::Base.transaction do
      pr.push_targets = new_push_targets
      # old value is set
      assert_array_equal original_push_targets.map(&:id), pr.push_targets_were
      pr.save
    end
    # old value should gone after save
    assert_nil pr.push_targets_were
    assert_array_equal new_push_targets, pr.push_targets
  end

  test "old values should not be set when set the same push targets" do
    pr = PackageRestriction.first
    expected_push_targets = pr.push_targets.to_a
    ActiveRecord::Base.transaction do
      pr.push_targets = expected_push_targets
      # old value should not be set
      assert_nil pr.push_targets_were
      pr.save
    end
    assert_array_equal expected_push_targets, pr.push_targets
  end

  test "old values should not be set if new record" do
    pr = PackageRestriction.new
    expected_push_targets = [@cdn]
    ActiveRecord::Base.transaction do
      pr.package = Package.find_by_name("qemu-kvm")
      pr.push_targets = expected_push_targets
      pr.variant = @variant_7Server
      # old value should not be set
      assert_nil pr.push_targets_were
      pr.save
    end
    assert_array_equal expected_push_targets, pr.push_targets
  end
end