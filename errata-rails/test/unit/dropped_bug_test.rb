require 'test_helper'

class DroppedBugTest < ActiveSupport::TestCase
  # For Bug 915556 - disallow non-SRT from removing CVEs or SecurityTracking bugs from RHSAs
  test "Security Bug Removal" do
    e = RHSA.find 11149
    fb = e.filed_bugs.where(:bug_id => 675792).first
    assert fb.bug.is_security?, "Should be a security bug"
    db = DroppedBug.new(:errata => e, :bug => fb.bug, :who => qa_user)
    refute db.valid?, "Should not be able to drop bug!"
    assert_errors_include(db, 'Bug Only the Security Team can remove security Bugs from an advisory')
    ex = assert_raise(ActiveRecord::RecordInvalid) { fb.destroy }
    assert_equal 'Validation failed: Bug Only the Security Team can remove security Bugs from an advisory', ex.message
    assert FiledBug.exists? fb.id

    db = DroppedBug.new(:errata => e, :bug => fb.bug, :who => secalert_user)
    assert_valid db
    fb = FiledBug.find fb.id
    with_current_user(secalert_user) do
      fb.destroy
    end
  end
end
