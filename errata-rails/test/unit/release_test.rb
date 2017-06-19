require 'test_helper'

class ReleaseTest < ActiveSupport::TestCase

  def release_fields
    { :description => 'blah', :ship_date => Time.now + 1.month }
  end

  def product_fields
    { :description => 'blah', :default_solution_id => 2, :state_machine_rule_set_id => StateMachineRuleSet.first.id }
  end

  def make_product_without_prefix
    Product.create! product_fields.merge :name => 'No-prefix Product', :short_name => 'NPP', :cdw_flag_prefix => nil
  end

  def make_product_with_prefix
    Product.create! product_fields.merge :name => 'Prefix Product',    :short_name => 'PP',  :cdw_flag_prefix => 'pp'
  end

  def test_blocker_flags
    product_without_prefix = make_product_without_prefix
    product_with_prefix = make_product_with_prefix

    # Create some releases (one of each type)
    quarterly_rel  = QuarterlyUpdate.create! release_fields.merge :name => 'FooQ 1.0.0', :product => product_without_prefix, :blocker_flags => 'fooq-1.0.0'
    zstream_rel    = Zstream.create!         release_fields.merge :name => 'FooZ 1.0.0', :product => product_without_prefix, :blocker_flags => 'fooz-1.0.0'
    fast_track_rel = FastTrack.create!       release_fields.merge :name => 'FooF 1.0.0', :product => product_without_prefix, :blocker_flags => 'foof-1.0.0,fast'
    async_rel      = Async.create!           release_fields.merge :name => 'FooA 1.0.0', :product => product_without_prefix, :blocker_flags => 'fooa-1.0.0'

    # Test the flags without any flag prefix (default)
    assert_equal %w[fooq-1.0.0     ], quarterly_rel. base_blocker_flags
    assert_equal %w[fooz-1.0.0     ], zstream_rel.   base_blocker_flags
    assert_equal %w[foof-1.0.0 fast], fast_track_rel.base_blocker_flags
    assert_equal %w[fooa-1.0.0     ], async_rel.     base_blocker_flags

    assert_equal %w[devel_ack qa_ack pm_ack], quarterly_rel. compulsory_blocker_flags
    assert_equal %w[devel_ack qa_ack pm_ack], zstream_rel.   compulsory_blocker_flags
    assert_equal %w[devel_ack qa_ack       ], fast_track_rel.compulsory_blocker_flags
    assert_equal %w[                       ], async_rel.     compulsory_blocker_flags

    assert_equal %w[fooq-1.0.0 devel_ack qa_ack pm_ack], quarterly_rel. blocker_flags
    assert_equal %w[fooz-1.0.0 devel_ack qa_ack pm_ack], zstream_rel.   blocker_flags
    assert_equal %w[foof-1.0.0 fast devel_ack qa_ack  ], fast_track_rel.blocker_flags
    assert_equal %w[fooa-1.0.0                        ], async_rel.     blocker_flags

    # Instead of making new dummy releases, let's just change their product
    # Change it to the one that does have a cdw_flag_prefix.
    [quarterly_rel, zstream_rel, fast_track_rel, async_rel].each do |release|
      release.update_attribute(:product, product_with_prefix)
    end

    # Now test the blocker flags with a flag prefix
    assert_equal %w[fooq-1.0.0     ], quarterly_rel. base_blocker_flags
    assert_equal %w[fooz-1.0.0     ], zstream_rel.   base_blocker_flags
    assert_equal %w[foof-1.0.0 fast], fast_track_rel.base_blocker_flags
    assert_equal %w[fooa-1.0.0     ], async_rel.     base_blocker_flags

    assert_equal %w[pp_devel_ack pp_qa_ack pp_pm_ack], quarterly_rel. compulsory_blocker_flags
    assert_equal %w[pp_devel_ack pp_qa_ack pp_pm_ack], zstream_rel.   compulsory_blocker_flags
    assert_equal %w[pp_devel_ack pp_qa_ack          ], fast_track_rel.compulsory_blocker_flags
    assert_equal %w[                                ], async_rel.     compulsory_blocker_flags

    assert_equal %w[fooq-1.0.0 pp_devel_ack pp_qa_ack pp_pm_ack], quarterly_rel. blocker_flags
    assert_equal %w[fooz-1.0.0 pp_devel_ack pp_qa_ack pp_pm_ack], zstream_rel.   blocker_flags
    assert_equal %w[foof-1.0.0 fast pp_devel_ack pp_qa_ack     ], fast_track_rel.blocker_flags
    assert_equal %w[fooa-1.0.0                                 ], async_rel.     blocker_flags
  end

  #
  # Compulsory blocker flags must not be included in Base blocker flags.
  # Bug: 1148962
  #
  test "base blocker flags" do
    product_without_prefix = make_product_without_prefix
    product_with_prefix = make_product_with_prefix

    # Create some releases (one of each type)
    quarterly_rel  = QuarterlyUpdate.create! release_fields.merge :name => 'FooQ 1.0.0', :product => product_without_prefix, :blocker_flags => 'fooq-1.0.0, devel_ack, qa_ack, pm_ack'
    zstream_rel    = Zstream.create!         release_fields.merge :name => 'FooZ 1.0.0', :product => product_without_prefix, :blocker_flags => 'fooz-1.0.0, devel_ack, qa_ack, pm_ack'
    fast_track_rel = FastTrack.create!       release_fields.merge :name => 'FooF 1.0.0', :product => product_without_prefix, :blocker_flags => 'foof-1.0.0,fast, devel_ack, qa_ack'
    async_rel      = Async.create!           release_fields.merge :name => 'FooA 1.0.0', :product => product_without_prefix, :blocker_flags => 'fooa-1.0.0, devel_ack, qa_ack, pm_ack'

    # Test the flags without any flag prefix (default)
    # Note that the compulsory flags must not be included in base_blocker_flags
    assert_equal %w[fooq-1.0.0                        ], quarterly_rel. base_blocker_flags
    assert_equal %w[fooz-1.0.0                        ], zstream_rel.   base_blocker_flags
    assert_equal %w[foof-1.0.0 fast                   ], fast_track_rel.base_blocker_flags
    assert_equal %w[fooa-1.0.0 devel_ack qa_ack pm_ack], async_rel.     base_blocker_flags

    assert_equal %w[fooq-1.0.0 devel_ack qa_ack pm_ack], quarterly_rel. blocker_flags
    assert_equal %w[fooz-1.0.0 devel_ack qa_ack pm_ack], zstream_rel.   blocker_flags
    assert_equal %w[foof-1.0.0 fast devel_ack qa_ack  ], fast_track_rel.blocker_flags
    assert_equal %w[fooa-1.0.0 devel_ack qa_ack pm_ack], async_rel.     blocker_flags

    # Instead of making new dummy releases, let's just change their product
    # Change it to the one that does have a cdw_flag_prefix.
    [quarterly_rel, zstream_rel, fast_track_rel, async_rel].each do |release|
      release.update_attribute(:product, product_with_prefix)
    end

    # Now test the blocker flags with a flag prefix
    # Note that the compulsory flags are not included in base_blocker_flags
    assert_equal %w[fooq-1.0.0                        ], quarterly_rel. base_blocker_flags
    assert_equal %w[fooz-1.0.0                        ], zstream_rel.   base_blocker_flags
    assert_equal %w[foof-1.0.0 fast                   ], fast_track_rel.base_blocker_flags
    assert_equal %w[fooa-1.0.0 devel_ack qa_ack pm_ack], async_rel.     base_blocker_flags

    assert_equal %w[fooq-1.0.0 pp_devel_ack pp_qa_ack pp_pm_ack], quarterly_rel. blocker_flags
    assert_equal %w[fooz-1.0.0 pp_devel_ack pp_qa_ack pp_pm_ack], zstream_rel.   blocker_flags
    assert_equal %w[foof-1.0.0 fast pp_devel_ack pp_qa_ack     ], fast_track_rel.blocker_flags
    assert_equal %w[fooa-1.0.0 devel_ack qa_ack pm_ack         ], async_rel.     blocker_flags
  end

  test "blocker and exception flags for components" do
    r = Release.find_by_name! "RHEL-5.7.0"
    assert r.allow_blocker?, "Release should allow blocker"
    assert r.allow_exception?, "Release should allow exception"
    assert_equal 1252, r.bugs.count
    r.allow_exception = false
    assert_equal 1252, r.bugs.count, "Bug count should not change with just exception removed based on test data"

    r.allow_blocker = false
    assert_equal 1250, r.bugs.count, "Should eliminate all non-security blocker only bugs"
    bug = r.bugs.last
    bug.update_attributes(
      :flags => "rhel-5.7.0+",
      :keywords => '',
      :is_exception => 1
    )
    assert_equal 1249, r.bugs.count, "Bug #{bug.id} not eliminated"
    refute r.bugs.include? bug
    r.allow_exception = true
    assert_equal 1250, r.bugs.count, "Bug #{bug.id} still eliminated"
    assert r.bugs.include? bug
  end

  test "eligible bugs for release" do
    r = QuarterlyUpdate.first
    b4r = BugsForRelease.new(r)
    bug = b4r.eligible_bugs.first
    bug.keywords = 'TestOnly'
    bug.bug_status = 'MODIFIED'
    bug.save!

    refute b4r.eligible_bugs.map(&:id).include?(bug.id)
    refute b4r.eligible_bugs.map(&:bug_status).include?('CLOSED')

    assert b4r.ineligible_bugs.map(&:id).include?(bug.id)
    refute FiledBug.exists?(bug.id)

    bug.bug_status = 'ON_QA'
    bug.save!

    assert b4r.eligible_bugs.map(&:id).include?(bug.id)
  end

  test "allow_pkg_dupes impact on eligibility" do
    r = QuarterlyUpdate.first
    refute r.allow_pkg_dupes?

    # These bugs are both for the same package
    bug1 = Bug.find(685086)
    bug2 = Bug.find(685088)
    assert_equal bug1.package, bug2.package

    b4r = BugsForRelease.new(r)
    assert b4r.eligible_bugs.include?(bug1)
    assert b4r.eligible_bugs.include?(bug2)

    advisory = RHBA.create!(
      :reporter => qa_user,
      :synopsis => 'test 1',
      :product => r.product,
      :release => r,
      :assigned_to => qa_user,
      :content => Content.new(:topic => 'test',
                              :description => 'test',
                              :solution => 'fix it')
    )
    fb = FiledBugSet.new(:bugs => [bug1], :errata => advisory)
    fb.save!

    # Adding bug1 should have made both bugs disappear from BugsForRelease;
    # bug1 because it is filed, bug2 because its package is already linked to an advisory
    refute b4r.eligible_bugs.include?(bug1)
    refute b4r.eligible_bugs.include?(bug2)

    r.allow_pkg_dupes = 1
    r.save!

    # now that package dupes are allowed, bug2 is again eligible for a new advisory in this release
    refute b4r.eligible_bugs.include?(bug1)
    assert b4r.eligible_bugs.include?(bug2)
  end

  test "eligble bugs by package" do
    expected = [Package.first, Package.last]
    buglist = []
    expected.cycle(2) do |p|
      b = mock("Bug")
      b.expects(:package).returns(p)
      buglist << b
    end

    r = QuarterlyUpdate.first
    b4r = BugsForRelease.new(r)
    b4r.stubs(:eligible_bugs).returns(buglist)
    assert_equal expected.sort_by(&:id), b4r.eligible_bugs_by_package.keys.sort_by(&:id)
  end

  test 'update releases job enqueued' do
    # creating/updating a release should always ensure the update releases job is enqueued
    QuarterlyUpdate.create! release_fields.merge :name => 'FooQ 1.0.0', :product => Product.first, :blocker_flags => 'fooq-1.0.0'
    Zstream.create! release_fields.merge :name => 'FooZ 1.0.0', :product => Product.first, :blocker_flags => 'fooq-1.0.0'
    FastTrack.create! release_fields.merge :name => 'FooF 1.0.0', :product => Product.first, :blocker_flags => 'fooq-1.0.0,fast'
    Async.create! release_fields.merge :name => 'FooA 1.0.0', :product => Product.first, :blocker_flags => 'fooq-1.0.0'

    assert_equal 1, Delayed::Job.where('handler like "%UpdateReleasesJob %"').count
  end

  #
  # Blocker flags are not compulsory for certain releases
  # (release.rb:113 - compulsory_blocker_flags. We need to make sure,
  # that we do not return empty filters, which can lead to invalid SQL.
  #
  # Bug: 1026559
  #
  test "no invalid bug filter if ack_flags are empty" do
    #
    # Note: the access to release.bugs does execute the SQL and catches
    # any potential SQL syntax errors. We don't mean to test the results
    # here since it might be subject to change.
    #
    release = Async.first
    assert release.blocker_flags.empty?
    assert_filter_matches /1 = 0/, release

    release.update_attribute('blocker_flags', 'mrg-2.3.x')
    assert_filter_matches /1 = 1/, release
    assert_filter_matches /#{Regexp.escape("flags like '%mrg-2.3.x+%'")}/, release

    release.update_attribute('blocker_flags', 'mrg-2.3.x, cpp-2.3.x')
    assert_filter_matches /#{Regexp.escape("flags like '%mrg-2.3.x+%'")}/, release
    assert_filter_matches /#{Regexp.escape("flags like '%cpp-2.3.x+%'")}/, release
  end

  def assert_filter_matches(regexp, release)
    # Execute to avoid b0rked SQL
    assert release.bugs
    assert_match regexp, release.bugs.to_sql
  end
end

