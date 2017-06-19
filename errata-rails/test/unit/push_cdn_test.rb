require 'test_helper'

class PushCdnTest < ActiveSupport::TestCase

  setup do
    @rhn_advisory = Errata.find(11110)
  end

  test "logs warning if no cdn repos can be found" do
    Settings.stubs(:enable_tps_cdn).returns(true)
    # I know it's cheating, but will suffice to test the logger warning
    @rhn_advisory.stubs(:supports_cdn?).returns(true)

    logs = capture_logs do
      Push::Cdn.get_repos_for_tps(@rhn_advisory)
    end
    first_entry = logs.first
    assert_match %r{No CDN repositories found}, first_entry[:msg]
    assert_equal 'WARN', first_entry[:severity]
  end

end
