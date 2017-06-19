require 'test_helper'

class RHSAFormIntegrationTest < ActionDispatch::IntegrationTest

  test "non-secalert user can create low security rhsa" do
    bug = Bug.unfiled.with_states('MODIFIED').last
    auth_as devel_user

    # for the purpose of this test, pretend all bugs are valid
    FiledBug.any_instance.stubs(:skip_bug_valid_checks? => true)

    visit '/errata/new'

    assert_difference('RHSA.count', 1) do
      # NOTE [capybara 2.0.3] can't choose 'Red Hat Security Advisory'
      # since it returns two radio buttons with that name (pdc and non-pdc)
      choose 'advisory_errata_type_rhsa'

      fill_in 'advisory[topic]', :with => 'topic'
      fill_in 'advisory[description]', :with => 'description'
      fill_in 'advisory[synopsis]', :with => 'synopsis'
      fill_in 'advisory[idsfixed]', :with => bug.id.to_s
      click_on 'Preview >'
      click_on "Save Errata"
    end

    advisory = RHSA.last

    # these fields should have been prefilled to the only permitted values
    assert_equal 'Low', advisory.security_impact
    assert_equal nil, advisory.embargo_date
  end

  test "non-secalert user can convert rhba to rhsa" do
    auth_as devel_user

    advisory = RHBA.find(11119)

    visit "/errata/edit/#{advisory.id}"
    # NOTE [capybara 2.0.3] can't choose 'Red Hat Security Advisory'
    # since it returns two radio buttons with that name (pdc and non-pdc)
    choose 'advisory_errata_type_rhsa'

    click_on "Preview >"
    click_on "Save Errata"

    advisory = RHSA.find(11119)

    # these fields should have been prefilled to the only permitted values
    assert_equal 'Low', advisory.security_impact
    assert_equal nil, advisory.embargo_date
  end

  test "non-secalert user cannot convert embargoed rhba to rhsa" do
    auth_as devel_user

    advisory = RHBA.find(11119)
    advisory.update_attribute(:release_date, 10.days.from_now)

    visit "/errata/edit/#{advisory.id}"

    # NOTE [capybara 2.0.3] can't choose 'Red Hat Security Advisory'
    # since it returns two radio buttons with that name (pdc and non-pdc)
    choose 'advisory_errata_type_rhsa'

    click_on "Preview >"
    assert_errors_shown(1,
      :match => %r{Embargo date cannot be set on RHSA by non-secalert users})
  end

  test "non-secalert user can bypass CVE problems when converting to RHSA" do
    auth_as devel_user

    advisory = RHBA.find(11119)

    visit "/errata/edit/#{advisory.id}"

    # NOTE [capybara 2.0.3] can't choose 'Red Hat Security Advisory'
    # since it returns two radio buttons with that name (pdc and non-pdc)
    choose 'advisory_errata_type_rhsa'

    # some CVE validations are on the errata model while others are on the
    # AdvisoryForm.  These cases aim to ensure that both sets of validations
    # are being applied.
    fill_in 'advisory[description]', :with => "#{advisory.description}\nCVE-1234-56"
    fill_in 'advisory[cve]', :with => 'CVE-1234-57'
    click_on "Preview >"
    text = page.find('#cve_warnings').text
    [
      %r{CVE-1234-56 appears in the description but not in the 'CVE names' list},
      %r{CVE-1234-57 is not correctly formatted},
      %r{The following CVE names appear in the CVE names list but not in the summary of any linked bugzilla bug: CVE-1234-57},
      %r{The following CVE names appear in the CVE names list but not in the aliases of any linked bugzilla bug: CVE-1234-57},
    ].each do |pattern|
      assert_match pattern, text
    end

    # Can save despite warnings...
    click_on 'Save Errata'

    assert_equal %w[CVE-1234-57], Errata.find(advisory.id).cve_list
  end

  test "secalert user can modify security impact and embargo date on RHSA" do
    auth_as secalert_user

    advisory = RHSA.find(11149)

    visit "/errata/edit/#{advisory.id}"
    choose 'Embargoed until:'
    fill_in 'advisory[release_date]', :with => '2024-11-10'
    select 'Critical', :from => 'advisory[security_impact]'

    click_on "Preview >"
    click_on "Save Errata"

    advisory.reload
    assert_equal '2024-11-10'.to_datetime, advisory.embargo_date
    assert_equal 'Critical', advisory.security_impact
  end

  test "non-secalert user cannot modify security impact or embargo date on RHSA" do
    auth_as devel_user

    advisory = RHSA.find(11149)

    visit "/errata/edit/#{advisory.id}"

    # all these fields should not be usable
    assert_raise(Capybara::ElementNotFound) {
      choose 'Embargoed until:'
    }
    assert_raise(Capybara::ElementNotFound) {
      fill_in 'advisory[release_date]', :with => '2024-11-10'
    }
    assert_raise(Capybara::ElementNotFound) {
      select 'Critical', :from => 'advisory[security_impact]'
    }
  end

  # impact and embargo date are restricted for non-secalert users and displayed
  # differently in the UI; ensure all combinations don't cause problems
  ['Low', 'Moderate'].each do |security_impact|
    [nil, '2024-11-10'.to_datetime].each do |embargo_date|
      embargoed = !embargo_date.nil?
      test "non-secalert user can modify some fields of #{security_impact} impact #{embargoed ? 'embargoed' : 'non-embargoed'} rhsa" do
        auth_as devel_user
        advisory = Errata.find(11149)
        assert_equal 'Moderate: JBoss Enterprise Web Server 1.0.2 update', advisory.synopsis

        advisory.update_attributes(
          :security_impact => security_impact,
          :release_date => embargo_date)

        newtopic = "#{advisory.topic} and some other stuff"

        visit "/errata/edit/#{advisory.id}"
        fill_in 'advisory[topic]', :with => newtopic

        click_on "Preview >"
        click_on "Save Errata"

        advisory.reload
        assert_equal newtopic, advisory.topic

        # the restricted fields naturally should be unmodified
        assert_equal security_impact, advisory.security_impact
        assert_equal embargo_date, advisory.embargo_date
      end
    end
  end

  def assert_errors_shown(count, args={})
    text = page.find('#errorExplanation').text
    assert_match %r{\b#{count} errors? prohibited this advisory from being saved}, text

    Array.wrap(args[:match]).each do |re|
      assert_match re, text
    end

    Array.wrap(args[:no_match]).each do |re|
      assert_no_match re, text
    end
  end
end
