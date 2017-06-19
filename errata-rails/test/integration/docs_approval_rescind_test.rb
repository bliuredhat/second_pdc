#
# We had some problems with advisory not being saved after
# its revision and doc_complete was updated in release 3.0.
#
# It was causing the docs approval not to be rescinded and
# the revision number not to be incremented properly after
# editing the advisory content. See bugs 875601 and 857417.
#
require 'test_helper'

class DocsApprovalRescindTest < ActionDispatch::IntegrationTest
  setup do
    # let this test focus only on the docs approval mails, ignore the mails for each advisory update
    CommentSweeper.any_instance.stubs(:after_commit => nil)
  end

  [[10836, :PUSH_READY], [11123, :QE]].each do |errata_id, initial_status|
    ['advisory_description', 'advisory_synopsis'].each do |modify_field|
      [false, true].each do |also_request_docs_approval|

        test "status #{initial_status} modify #{modify_field} with request approval #{also_request_docs_approval ? 'checked' : 'unchecked'}" do
          do_edit(errata_id, initial_status, docs_user, modify_field, also_request_docs_approval)
        end

      end
    end
  end

  def do_edit(errata_id, initial_status, as_user, modify_field, request_docs_approval)

    # Sanity check initial status and docs_approved?
    errata = Errata.find(errata_id)
    assert errata.status_is?(initial_status), "unexpected fixture data: #{errata.status} instead of #{initial_status}"
    assert errata.docs_approved?, "unexpected fixture data: should have docs approved"

    # Remember these for later
    orig_revision = errata.revision
    orig_comment_count = errata.comments.count
    orig_fulladvisory = errata.fulladvisory
    orig_deliveries_count = ActionMailer::Base.deliveries.count

    # Now let's edit it
    auth_as as_user
    visit "/errata/edit/#{errata.id}"

    orig_content = page.find("##{modify_field}").value
    fill_in modify_field, :with => "#{orig_content} FROB"

    click_button 'Preview >'
    assert_match %r{/errata/preview/#{errata.id}$}, current_url

    # Because docs are currently approved the user gets a warning
    assert_warning_message(initial_status)

    # Check request docs approval maybe
    check 'advisory_request_docs_approval_after_persist' if request_docs_approval

    # Save it for real
    click_button 'Save Errata'
    assert_match %r{/errata/details/#{errata.id}$}, current_url

    # Sanity check the update
    assert page.has_content?("FROB"), "Can't find the FROB!"

    # Reload the errata so we aren't using stale cached info
    errata = Errata.find(errata.id)

    # Now the important parts:
    assert_docs_approval_rescind(errata, initial_status, request_docs_approval)

    # Also the revision number should be incremented (and in the 'fulladvisory' text too)
    # (This was Bug 857417.)
    assert_equal orig_revision.next, errata.revision, "didn't increment revision"
    assert_equal orig_fulladvisory.next, errata.fulladvisory, "didn't increment fulladvisory" # (String#next is coool)

    expected_comment_texts = [
      "Documentation approval rescinded due to a docs update",
      ("Changed state from PUSH_READY to REL_PREP\nDocumentation is no longer approved" if initial_status == :PUSH_READY),
      ("Documentation approval requested." if request_docs_approval)
    ].compact

    assert_comment_texts_equal(expected_comment_texts, errata, orig_comment_count)

    # Let's check emails are sent as expected
    expected_emails = [
      { :subject => "#{Regexp.escape(errata.advisory_name)}.*Docs changed", :body => "Modified by #{as_user.realname}.*FROB" },
      ({ :subject => "Text ready for review", :body => "has been marked READY for documentation approval" } if request_docs_approval)
    ].compact

    assert_emails_deliver(expected_emails, orig_deliveries_count)
  end

  test "update bugs should cause rescind docs approval" do
    # Only secalert user can add or drop security bugs outside of NEW_FILES
    user = secalert_user
    auth_as user

    errata = Errata.find(11110)
    orig_comment_count = errata.comments.count
    orig_deliveries_count = ActionMailer::Base.deliveries.count
    initial_status = errata.status.to_sym

    assert initial_status == :PUSH_READY, "Fixture error, Errata #{errata.id} is no longer PUSH_READY"

    new_bug_ids  = [697042, 1139115].sort
    new_bugs     = Bug.find(new_bug_ids)
    new_bug_cves = new_bugs.map(&:alias).join(" ")
    drop_bug_ids = [692421]
    drop_bugs    = Bug.find(drop_bug_ids)

    new_jira_issue_keys = %w[TEIID-1672 TEIID-952]
    new_jira_issues = JiraIssue.find_by_key(new_jira_issue_keys)

    Bug.any_instance.stubs(:status).returns("MODIFIED")
    JiraIssue.any_instance.stubs(:is_security?).returns(true)

    visit "/errata/edit/#{errata.id}"

    fill_in :advisory_idsfixed, :with => (new_bug_ids + new_jira_issue_keys).join(" ")
    fill_in :advisory_cve, :with => new_bug_cves

    orig_content = page.find("#advisory_description").value
    fill_in :advisory_description, :with => "#{orig_content} #{new_bug_cves}"

    click_button 'Preview >'
    assert_match %r{/errata/preview/#{errata.id}$}, current_url

    # Because docs are currently approved the user gets a warning
    assert_warning_message(initial_status)

    # Check bug changes are shown as expected
    assert has_text?("Bugs/JIRA Issues changed:"), "Missing 'Changes' section"
    assert has_text?("+ #{(new_bug_ids + new_jira_issue_keys).join(" ")}"), "Added issues not match or not show"

    # Check request docs approval maybe
    check 'advisory_request_docs_approval_after_persist'

    # Save it for real
    click_button 'Save Errata'
    assert_match %r{/errata/details/#{errata.id}$}, current_url

    # Reload the errata so we aren't using stale cached info
    errata = Errata.find(errata.id)
    assert_docs_approval_rescind(errata, initial_status, true)

    # Let's check comments are added as expected
    expected_comment_texts = [
      "Documentation approval rescinded due to bugs added",
      "Changed state from PUSH_READY to REL_PREP\nDocumentation is no longer approved",
        "\n__div_bug_states_separator\nThe following bugs have been added:\nbug 697042 - " +
        "CVE-2011-1586 kdenetwork: incomplete fix for CVE-2010-1000\nbug 1139115 - CVE-2014-3615 " +
        "Qemu: information leakage when guest sets high resolution\n__end_div\n",
      "\n__div_bug_states_separator\nThe following bugs have been removed:\nbug 692421 - CVE-2011-1484 " +
        "JBoss Seam privilege escalation caused by EL interpolation in FacesMessages\n__end_div\n",
      "\n__div_bug_states_separator\nThe following JIRA issues have been added:\nJIRA issue TEIID-1672 - " +
        "Log client IP Address when Session is created\nJIRA issue TEIID-952 - Column level security capabilities\n__end_div\n",
      "Documentation approval requested.",
    ]
    assert_comment_texts_equal(expected_comment_texts, errata, orig_comment_count)

    # Let's check emails are sent as expected
    expected_emails = [
      { :subject => "#{Regexp.escape(errata.advisory_name)}.*Docs changed", :body => "Modified by #{user.realname}" },
      { :subject => "Text ready for review", :body => "has been marked READY for documentation approval" },
    ]
    assert_emails_deliver(expected_emails, orig_deliveries_count)
  end

  def assert_docs_approval_rescind(errata, initial_status, request_docs_approval)
    # Supposed to have automatically rescind the docs approval
    # and move the status back to REL_PREP if if was PUSH_READY.
    # (This was Bug 875601.)
    assert !errata.docs_approved?, "docs approval not rescinded!"

    expected_status = initial_status == :PUSH_READY ? :REL_PREP : initial_status
    assert errata.status_is?(expected_status), "advisory status should be #{expected_status}"

    # Check if docs approval was requested if user checked it
    assert_equal request_docs_approval, errata.docs_approval_requested?, "unexpected docs approval status"
  end

  def assert_warning_message(status)
    within('.infobox.smaller div') do
      assert has_text?("WARNING")
      assert has_text?("This advisory has docs approval.")
      assert_equal status == :PUSH_READY, has_text?("move it from PUSH_READY back to REL_PREP.")
    end
  end

  def assert_comment_texts_equal(expected_comment_texts, errata, start_from_comment)
    new_comment_texts = [*start_from_comment...errata.comments.count].map { |i| errata.comments[i].text }
    assert_array_equal expected_comment_texts, new_comment_texts
  end

  def assert_emails_deliver(expected_emails, start_from_email)
    actual_emails = [*start_from_email...ActionMailer::Base.deliveries.count].map { |i| ActionMailer::Base.deliveries[i] }

    assert_equal expected_emails.size, actual_emails.count, "New emails count not match"

    expected_emails.each_with_index do |expected, i|
      assert_match /#{expected[:subject]}/, actual_emails[i].subject, "Email subject not match"
      assert_match /#{expected[:body]}/m, actual_emails[i].body.to_s, "Email body not match"
    end
  end
end
