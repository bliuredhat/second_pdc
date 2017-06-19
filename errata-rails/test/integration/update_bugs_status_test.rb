require 'test_helper'

class UpdateBugsStatusTest < ActionDispatch::IntegrationTest

  setup do
    auth_as releng_user
  end

  test 'current status should be empty' do
    errata = Errata.find(7058)
    bug_a, bug_b = errata.bugs
    assert_equal 'CLOSED', bug_a.bug_status
    assert_equal 'CLOSED', bug_b.bug_status
    new_status = 'ASSIGNED'

    Bugzilla::TestRpc.any_instance.expects(:changeStatus).once.
      with(bug_a.id, new_status,
           bug_comment(bug_a, new_status, errata)).
      returns(true)

    visit "/bugs/updatebugstates/#{errata.id}"

    assert page.has_content?('Update Bug Statuses for Advisory')
    # Verify combo box doesn't have value as default
    assert find("#bug_#{bug_a.bug_id}").value.empty?
    assert find("#bug_#{bug_b.bug_id}").value.empty?

    select('ASSIGNED', :from => "bug_#{bug_a.bug_id}")

    click_on 'Update'

    errata.reload
    bug_a, bug_b = errata.bugs
    assert_equal new_status, bug_a.bug_status
    assert_equal 'CLOSED', bug_b.bug_status
  end

  def bug_comment(bug, new_state, errata)
    "Bug report changed from #{bug.bug_status} to #{new_state} " +
      "status by the Errata System: \n" +
      "Advisory #{errata.fulladvisory}: \n" +
      "Changed by: #{releng_user.to_s}\n" +
      "http://errata.devel.redhat.com/advisory/#{errata.id}\n\n"
  end
end
