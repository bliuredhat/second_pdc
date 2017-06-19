require 'test_helper'

class ErrataTestRequirementsTest < ActiveSupport::TestCase
  setup do
    @rpm_only_advisory = Errata.find(11065)
    @unlocked_nonrpm_only_advisory = Errata.find(16397)
    @locked_nonrpm_only_advisory = @unlocked_nonrpm_only_advisory.dup
    @locked_nonrpm_only_advisory.stubs(:filelist_locked? => true)
    @mixed_advisory = Errata.find(16396)
    @textonly_advisory = Errata.find(16375)
  end

  test 'testdata preconditions' do
    @rpm_only_advisory.build_mappings.tap{|m|
      assert m.any?
      assert m.all?(&:for_rpms?)
    }
    @unlocked_nonrpm_only_advisory.build_mappings.tap{|m|
      assert m.any?
      assert m.all?(&:for_nonrpms?)
    }
    @mixed_advisory.build_mappings.tap{|m|
      assert m.any?
      refute m.all?(&:for_rpms?)
      refute m.all?(&:for_nonrpms?)
    }
    assert @textonly_advisory.text_only?
  end

  [
    [:rpm_only_advisory,             :tps,     true],
    [:rpm_only_advisory,             :rpmdiff, true],
    [:mixed_advisory,                :tps,     true],
    [:mixed_advisory,                :rpmdiff, true],
    [:textonly_advisory,             :tps,     false],
    [:textonly_advisory,             :rpmdiff, false],
    [:unlocked_nonrpm_only_advisory, :tps,     false],
    [:unlocked_nonrpm_only_advisory, :rpmdiff, false],
    [:locked_nonrpm_only_advisory,   :tps,     false],
    [:locked_nonrpm_only_advisory,   :rpmdiff, false],
  ].each do |advisory, test_type, expected|
    test "#{advisory} #{expected ? 'requires' : 'does not require'} #{test_type}" do
      e = self.instance_variable_get("@#{advisory}")
      method = :"requires_#{test_type}?"
      assert_equal expected, e.send(method), "advisory #{e.id} #{method} should have been #{expected}"
    end
  end
end
