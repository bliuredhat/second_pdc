require 'test_helper'

class PushTypeTest < ActiveSupport::TestCase
  # Validate that existing advisories can at least push to rhn
  test "Push Targets" do
    Errata.where('id < ?', 16396).where('synopsis NOT LIKE "%CDN Only%"').each do |e|
      next if e.status == State::DROPPED_NO_SHIP
      next if !e.text_only? && e.brew_builds.empty?
      assert e.supports_rhn_stage?, "Advisory #{e.id} no rhn stage?"
      assert e.supports_rhn_live?, "Advisory #{e.id} no rhn live?"
    end
  end

  test 'advisory not supporting altsrc works as expected' do
    # jboss-related advisory, doesn't use altsrc
    e = Errata.find(11110)
    refute e.supports_altsrc?

    blockers = e.push_altsrc_blockers
    refute blockers.empty?
    assert_match %r{\bAltsrc pushes are not supported\b}, blockers.map(&:to_s).join
  end

  [
    # preconditions (methods which are mocked to return true), followed by expected blockers.
    # This is intended to exercise every code path for the relationship between altsrc
    # blockers and RHN/CDN blockers.
    [[:has_rhn_live?],
     ['This errata cannot be pushed to RHN Live, thus may not be pushed to git']],

    [[:has_rhn_live?, :can_push_rhn_live?],
     []],

    # if it has CDN, but cannot push to CDN, it cannot push to altsrc
    [[:has_rhn_live?, :can_push_rhn_live?, :has_cdn?],
     ['This errata cannot be pushed to CDN Live, thus may not be pushed to git']],

    [[:has_rhn_live?, :can_push_rhn_live?, :has_cdn?, :can_push_cdn_if_live_push_succeeds?],
     []],

    [[:has_cdn?],
     ['This errata cannot be pushed to CDN Live, thus may not be pushed to git']],

    [[:has_cdn?, :can_push_cdn?],
     []],

    [[], []],
  ].each_with_index do |(true_things,expected_blockers),index|
    test "advisory altsrc blockers as expected - case #{index}" do
      e = Errata.find(10836)
      [
        :has_rhn_live?,
        :can_push_rhn_live?,
        :has_cdn?,
        :can_push_cdn_if_live_push_succeeds?,
        :can_push_cdn?
      ].each do |thing|
        if true_things.include?(thing)
          e.expects(thing).at_least_once.returns(true)
        else
          e.stubs(thing).returns(false)
        end
      end

      assert_equal expected_blockers, e.push_altsrc_blockers,
        "blockers not as expected when #{true_things.inspect} are true"
    end
  end
end
