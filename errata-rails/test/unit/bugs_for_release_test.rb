require 'test_helper'

class BugsForReleaseTest < ActiveSupport::TestCase

  # FIXME: these are bugs incorrectly provided by BugsForRelease at the time this test was written.
  # Remove them from this list when the underlying cause is resolved!
  KNOWN_WRONG_BUGS = {
    # Bug 1082388
    'RHEL-5.7.0' => [693759],
    'RHEL-6.1.0' => [
      610466,
      645648,
      645799,
      670925,
      675118,
      676018,
      678294,
      679344,
      691419,
      696131,
      697504,
    ]
  }

  # A few releases to use for the test.
  RELEASES = %w[
    FAST5.7
    RHEL-5.7.0
    RHEL-6.1.0
    RHEL-6.5.z
    RHEL-6.6.z
    RHEL-7.0.Z
    RHEL-7.1.Z
    RHEL-7.2.0
  ]

  RELEASES.each do |release_name|
    test "compatible with checklist #{release_name}" do
      release = Release.find_by_name!(release_name)
      release_bugs = release.bugs.unfiled.select{|b| b.bug_status != 'CLOSED'}
      checklist_bugs = eligible_by_checklist release, release_bugs

      b4r = BugsForRelease.new(release)
      expected_bug_ids = checklist_bugs.map(&:id)
      actual_bug_ids = b4r.eligible_bugs.map(&:id)

      missing_bugs = expected_bug_ids - actual_bug_ids
      wrong_bugs = (actual_bug_ids - expected_bug_ids).sort
      expected_wrong_bugs = (KNOWN_WRONG_BUGS[release.name] || []).sort

      assert missing_bugs.empty?, "These bugs are eligible according to BugEligibility, but are missing from BugsForRelease: #{missing_bugs.inspect}"
      assert_equal expected_wrong_bugs, wrong_bugs, "These bugs are ineligible according to BugEligibility, but are still provided by BugsForRelease:\n#{ineligible_reasons(release, wrong_bugs)}"
    end
  end

  # TODO: test ineligible as well!

  def eligible_by_checklist(release, bugs)
    bugs.select do |b|
      BugEligibility::CheckList.new(b, :release => release).pass_all?
    end
  end

  def ineligible_reasons(release, bug_ids)
    bug_ids.map do |b|
      cl = BugEligibility::CheckList.new(Bug.find(b), :release => release)
      messages = cl.checks.map(&:message).map{|s| "    #{s}"}.join("\n")
      "  #{b}:\n#{messages}"
    end.join("\n")
  end

end
