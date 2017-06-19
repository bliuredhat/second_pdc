require 'test_helper'

class PushPolicyTest < ActiveSupport::TestCase

  setup do
    @cdn_advisory = Errata.find(16374)
    @rhn_advisory = Errata.find(11110)
    @rhn_cdn_advisory = Errata.find(10836)
    @rhn_nopush_advisory = Errata.find(11152)
  end

  test "raises ArgumentError if created with wrong push type" do
    assert_raises(ArgumentError) { Push::Policy.new(@cdn_advisory, :invalid) }
  end

  test "successfully returns live push policies for push targets from errata" do
    policies = Push::Policy.policies_for_errata(@rhn_cdn_advisory)
    assert_equal 5, policies.count
    assert policies.reject { |policy| policy.class.staging == false }.empty?
  end

  test "successfully returns mandatory or optional live push policies for push targets from errata" do
    [
       [ ['rhn_live', 'cdn_live', 'cdn_docker'], {:mandatory => true} ],
       [ ['ftp', 'altsrc'], {:mandatory => false} ],
       [ ['rhn_live', 'cdn_live', 'cdn_docker', 'ftp', 'altsrc'], {} ]
    ].each do |targets, opts|
      policies = Push::Policy.policies_for_errata(@rhn_cdn_advisory, opts)
      assert_array_equal targets, policies.map(&:push_type).map(&:to_s)
    end
  end

  test "push policy is not applicable when has_target returns false" do
    @rhn_cdn_advisory.stubs(:has_ftp? => false)
    @rhn_cdn_advisory.stubs(:has_rhn_live? => false)

    [
      [:ftp, false],
      [:rhn_live, false],
      [:cdn, true],
    ].each do |policy, expect_applicable|
      Push::Policy.new(@rhn_cdn_advisory, policy).tap{|p|
        assert_equal expect_applicable, p.push_applicable?, "mismatch for policy #{policy}"
      }
    end
  end

  test "successfully returns staging policies only for push targets from errata" do
    policies = Push::Policy.policies_for_errata(@rhn_cdn_advisory, :staging => true)
    assert_equal 3, policies.count
    assert policies.reject { |policy| policy.class.staging == true }.empty?
  end

  test "cdn rhn live push not possible with required targets" do
    [[@cdn_advisory, :rhn_live], [@rhn_advisory, :cdn]].each do |advisory, type|
      policy = Push::Policy.new(advisory, type)
      refute policy.push_possible?
      assert_match %r{not supported}, policy.errors.full_messages.join
    end
  end

  test "returns false if advisory has already been pushed without pub task" do
    policy = Push::Policy.new(@cdn_advisory, :cdn)
    job = CdnPushJob.new(:errata => @cdn_advisory, :pushed_by => releng_user)
    job.save!
    job.mark_as_complete!

    # has_pushed? is only supposed to cover push jobs which really
    # triggered pub, so this push job won't count as pushed.
    refute policy.has_pushed?
  end

  test "returns true if advisory has already been pushed with pub task" do
    policy = Push::Policy.new(@cdn_advisory, :cdn)
    job = CdnPushJob.new(:errata => @cdn_advisory, :pushed_by => releng_user)
    job.pub_task_id = PushJob.pluck('max(pub_task_id)').first + 100
    job.save!
    job.mark_as_complete!

    assert policy.has_pushed?
  end

  test "returns false if advisory has not been pushed yet" do
    # note this advisory has a nochannel job, so this also tests that nochannel jobs
    # don't count towards has_pushed?
    CdnPushJob.for_errata(@cdn_advisory).tap do |jobs|
      refute jobs.empty?
      assert jobs.excluding_nochannel.empty?
    end

    refute Push::Policy.new(@cdn_advisory, :cdn).has_pushed?
  end

  test "can not push if no ftp file map" do
    @cdn_advisory.expects(:push_ftp_blockers).returns([])
    @cdn_advisory.expects(:supported_push_types).returns([:ftp])

    policy = Push::Policy.new(@cdn_advisory, :ftp)
    policy.expects(:ftp_paths).returns([])

    refute policy.push_possible?
    assert_match %r{File List is empty}i, policy.errors.values.join
  end

  test "can not push CDN if can't push to RHN Live" do
    @rhn_cdn_advisory.expects(:can_push_rhn_live?).at_least_once.returns(false)
    policy = Push::Policy.new(@rhn_cdn_advisory, :cdn)

    refute policy.push_possible?
    assert_match %r{\bcannot be pushed to RHN Live, thus may not be pushed to CDN\b}i, policy.errors.values.join
  end

  test "text only advisory can push to cdn" do
    text_only = Errata.where(:text_only => 1).last
    text_only.expects(:release_versions_used_by_advisory).at_least_once.returns(@cdn_advisory.release_versions_used_by_advisory)
    text_only.expects(:product_versions).never

    policy = Push::Policy.new(text_only, :cdn)
    policy.expects(:push_type_supported?).at_least_once.returns(true)
    policy.expects(:can_push?).returns(true)

    assert policy.push_possible?
    assert policy.push_applicable?
    assert policy.errors.empty?
  end

  test "text only advisory can not push Altsrc" do
    text_only = Errata.where(:text_only => 1).select(&:supports_altsrc?).last
    policy = Push::Policy.new(text_only, :altsrc)

    refute policy.push_possible?
    assert_match %r{\bCan't push advisory to Altsrc now due to: There are no packages available to push to git\b}, policy.errors.values.join
  end

  test 'policies are ordered appropriately' do
    RHBA.any_instance.expects(:supported_push_types).at_least_once.returns(
      [:ftp, :cdn, :rhn_live, :altsrc, :cdn_stage, :rhn_stage])
    actual_live_order = Push::Policy.policies_for_errata(RHBA.first).map(&:push_type)
    actual_staging_order = Push::Policy.policies_for_errata(RHBA.first, :staging => true).map(&:push_type)
    assert_equal [:rhn_live, :cdn_live, :ftp, :altsrc], actual_live_order
    assert_equal [:rhn_stage, :cdn_stage], actual_staging_order
  end
end
