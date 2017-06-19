#
# See lib/bugzilla_eligibility and lib/check_list
#
require 'test_helper'

class BugEligibilityTest < ActiveSupport::TestCase

  setup do
    @bug = @bug_with_release = Bug.find(698060)
    @release = @bug.guess_release_from_flag
    @bug_without_release = Bug.first
  end

  def get_check(check_type, bug, opts={})
    BugEligibility::CheckList.const_get(check_type).new(bug, opts)
  end

  def do_check(check_type, bug, expect_pass, expect_message_match, opts={})
    check = get_check(check_type, bug, opts)
    assert_equal expect_pass, check.pass?
    assert_match expect_message_match, check.message
  end

  test "is the bug in a valid state" do
    @bug.bug_status = 'CLOSED'
    do_check(:CorrectBugState, @bug, false, /Requires status .+ The bug is currently CLOSED/)

    @bug.bug_status = 'VERIFIED'
    do_check(:CorrectBugState, @bug, true, /status is correct/)

    #
    # Bugs with a TestOnly Keyword are only allowed in ['VERIFIED',
    # 'ON_QA'] states
    # Bug: https://bugzilla.redhat.com/show_bug.cgi?id=998852
    #
    @bug.keywords = 'TestOnly'
    @bug.bug_status = 'MODIFIED'
    do_check(:CorrectBugState, @bug, false, /bug is currently/)
  end

  test "what are valid bug states" do
    check = get_check(:CorrectBugState, @bug)
    assert_equal @release.valid_bug_states, check.valid_bug_states
    assert_equal ['VERIFIED', 'MODIFIED'].sort, check.valid_bug_states.sort

    # Red Hat Storage. The product has different bug states to the default.
    rhs_product_version = ProductVersion.find_by_id(215)
    @release.update_attribute(:product_versions, [rhs_product_version])
    assert_equal @release.valid_bug_states, get_check(:CorrectBugState, @bug).valid_bug_states
  end

  test "is the bug filed in an existing advisory" do
    assert @bug.errata.empty?
    do_check(:PartOfAdvisory, @bug, true, /not filed on any existing/)

    bug = FiledBug.first.bug
    do_check(:PartOfAdvisory, bug, false, /is filed alread/, :release => @release, :bug => bug)
  end

  test "is the bug part of an approved component" do
    zstream = mock('Zstream')
    #zstream.expects(:kind_of?).at_least_once.with(Zstream).returns(true)
    #zstream.expects(:class).once.returns(mock(:name => 'Zstream'))
    zstream.expects(:supports_component_acl?).at_least_once.returns(false)
    do_check(:PartOfComponent, @bug, true, /is on the approved component list/)

    @release.approved_components = []
    do_check(:PartOfComponent, @bug, false, /component list for #{@release.name} is currently empty/)

    do_check(:PartOfComponent, @bug, true, /Not needed for release type/, :release => Async.first)
    do_check(:PartOfComponent, @bug, true, /Not needed for release type/, :release => zstream)
  end

  test "Check for correct release flags" do
    do_check(:CorrectFlags, @bug, true, /required flags are present/)

    release = Release.last
    release.stubs(:has_correct_flags?).returns(false)
    release.stubs(:blocker_flags).returns(%w[foo bar])
    do_check(:CorrectFlags, @bug_without_release, false, /must have the following acked flags: foo, bar/, :release => release)
  end

  test "is the bug part of a component for which an advisory exist" do
    do_check(:AdvisoryForComponent, @bug, true, /No existing advisory for package/)

    @bug.package = @release.errata.first.packages.first
    do_check(:AdvisoryForComponent, @bug, false, /should be added to the existing advisory/)

    @release.allow_pkg_dupes = true
    @release.save!
    do_check(:AdvisoryForComponent, @bug, true, /Release #{Regexp.quote(@release.name)} allows more than one advisory for a single package/)

    release = mock()
    release.expects(:is_ystream?).at_least_once.returns(false)
    release.stubs(:name).returns('FastTrackRelease')
    release.stubs(:allow_pkg_dupes?).returns(false)
    do_check(:AdvisoryForComponent, @bug, true, /No existing advisory/, :release => release)
  end

  test 'bug 1071784 - release component for this advisory' do
    active_errata = @release.errata.first
    other_errata = @release.errata.second

    # release component is not assigned to any advisory, not testing for any particular advisory -> pass
    do_check(:PartOfComponent, @bug, true, /is on the approved component list/)

    # release component is assigned to some advisory, not testing for any particular advisory -> fail
    ReleaseComponent.where(:release_id => @release, :package_id => @bug.package_id).update_all(:errata_id => active_errata)
    do_check(:PartOfComponent, @bug, false, /is already covered in the release by #{active_errata.advisory_name}/)

    # release component is assigned to some advisory, and testing for that advisory -> pass
    do_check(:PartOfComponent, @bug, true, /is on the approved component list/, :errata => active_errata)

    # release component is assigned to some advisory, and testing for some other advisory -> fail
    do_check(:PartOfComponent, @bug, false, /is already covered in the release by #{other_errata.advisory_name}/, :errata => other_errata)

    @release.allow_pkg_dupes = true
    @release.save!
    do_check(:PartOfComponent, @bug, true, /is on the approved component list/, :errata => other_errata)
  end

  test 'pdc release checks product valid bug states' do
    # Choose a bug in NEW and a PDC Release
    bug = Bug.find 698089
    assert_equal 'NEW', bug.bug_status
    release = Release.find_by_name 'PDCTestRelease'
    assert release.is_pdc?

    # Check should fail as bug is NEW
    assert_equal ['MODIFIED', 'VERIFIED'], release.product.valid_bug_states
    bug.stubs(:guess_release_from_flag).returns(release)
    do_check(:CorrectBugState, bug, false, /Requires status .+ The bug is currently NEW/)

    # Ensure that check passes when product's valid bug states changed
    release.product.stubs(:valid_bug_states).returns(%w(NEW ON_DEV ASSIGNED POST ON_QA))
    do_check(:CorrectBugState, bug, true, /status is correct\. \(One of NEW, ON_DEV, ASSIGNED, POST, ON_QA\)/)
  end

  # https://bugzilla.redhat.com/show_bug.cgi?id=1441880
  test 'can file bug in both pdc and non-pdc advisories' do
    pdc_advisory = Errata.find 21131
    assert pdc_advisory.is_pdc?, "Advisory should be PDC"
    assert_equal 'NEW_FILES', pdc_advisory.status
    regular = Errata.find 22001
    refute regular.is_pdc?, "Should not be a pdc advisory"
    assert_equal 'NEW_FILES', regular.status

    bug = pdc_advisory.bugs.first
    regular.release.stubs(:has_correct_flags?).returns(true)
    regular.release.stubs(:supports_component_acl?).returns(false)

    fb = FiledBug.new(errata: regular, bug: bug)
    assert fb.valid?, fb.errors.full_messages.join("\n")

    other_pdc_advisory = Errata.find 24627
    assert other_pdc_advisory.is_pdc?, "Advisory should be PDC"
    assert_equal 'NEW_FILES', other_pdc_advisory.status
    fb = FiledBug.new(errata: other_pdc_advisory, bug: bug)
    refute fb.valid?, "FiledBug should not be valid, bug is in other PDC advisory"
    assert_equal "Bug #1196142 The bug is filed already in RHBA-2015:2399, RHBA-2016:2399.", fb.errors.full_messages.join('')
  end
end
