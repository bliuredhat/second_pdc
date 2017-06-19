require 'test_helper'

class ExternalTestsTest < ActionDispatch::IntegrationTest

  setup do
    rhba_async.state_machine_rule_set.test_requirements << 'covscan'
    rhba_async.state_machine_rule_set.save!
    @test_run = rhba_async.create_external_test_run_for(:covscan, :external_id => 123)
  end

  def covscan_tab_url
    url_for(:controller => :external_tests, :action => :list, :id => rhba_async,
            :test_type => :covscan)
  end

  test "advisory covscan tab provides update status link" do
    auth_as admin_user

    visit covscan_tab_url
    assert has_link?("Refresh test status")
  end

  test "advisory covscan tab provides link to test details" do
    auth_as qa_user

    visit covscan_tab_url
    within('table.bug_list') { first(:link, 'View').click }
    assert has_text?(@test_run.status)
    assert has_text?('Covscan Message')
  end

  test 'ccat auto vs manual displays as expected' do
    auth_as qa_user

    errata_id = 13147

    test_runs = ExternalTestRun.where(:errata_id => errata_id).order('id asc')

    # This advisory has some failed tests, both ccat and ccat/manual
    assert_equal(
      ['ccat FAILED', 'ccat/manual FAILED', 'ccat FAILED'],
      test_runs.map{|run| "#{run.name} #{run.status}"})

    # On summary page, it should say that there are problems
    visit "/advisory/#{errata_id}"
    assert has_text?('There are CDN content verification problems')

    # Should be able to click CCAT tab and see the same result
    within('.eso-tab-bar') do
      click_on 'CCAT'
    end

    assert has_text?('All passed or waived? No')

    # Both test types should be displayed; the 'manual' test should be
    # highlighted as such
    assert has_text?('343 (manual)')
    assert has_text?('1983')
    refute has_text?('1983 (manual)')

    # If the auto run becomes passed, that doesn't affect the result, since it
    # is not active (manual run supersedes it)
    test_runs.first.update_attributes(:status => 'PASSED')

    visit "/advisory/#{errata_id}"
    assert has_text?('There are CDN content verification problems')

    within('.eso-tab-bar') do
      click_on 'CCAT'
    end

    assert has_text?('All passed or waived? No')

    # If the manual run becomes passed, CCAT overall is considered as passed.
    test_runs.second.update_attributes(:status => 'PASSED')

    visit "/advisory/#{errata_id}"
    assert has_text?('CDN content has been verified')

    within('.eso-tab-bar') do
      click_on 'CCAT'
    end

    assert has_text?('All passed or waived? Yes')
  end

  test 'ccat run cannot be refreshed or rescheduled if no issue URL present' do
    assert_nil ExternalTestRun.find(80).issue_url

    auth_as devel_user
    visit '/advisory/19435/test_run/80'
    assert has_text?('About CDN Content Availability')
    assert has_no_content?('Refresh test status')
    assert has_no_content?('Reschedule test')
  end

  test 'ccat can be rescheduled if issue URL present and failed' do
    assert ExternalTestRun.find(85).issue_url
    assert_equal 'FAILED', ExternalTestRun.find(85).status
    MessageBus.expects(:send_message).with do |body,dest,_|
      dest == 'ccat.reschedule_test' &&
      body['ERRATA_ID'] == '13147' &&
      body['JIRA_ISSUE_ID'] == 'https://projects.engineering.redhat.com/browse/ISSUE-891234' &&
      body['TARGET'] == 'cdn-live'
    end.once

    auth_as devel_user
    visit '/advisory/19435/test_run/85'
    assert has_text?('About CDN Content Availability')
    # Refreshing is not supported yet
    assert has_no_content?('Refresh test status')
    assert has_content?('Reschedule test')

    click_link 'Reschedule test'
    assert has_text? 'Scan for ccat rescheduled.'
  end

  test 'CCAT hidden when CDN is not applicable' do
    e = Errata.find(20291)

    # Although this advisory supports CDN, and CCAT is in the workflow, it won't
    # be pushing anything to CDN
    assert e.supports_cdn?
    assert e.requires_external_test?(:ccat)
    refute e.has_cdn?

    auth_as devel_user
    visit "/advisory/#{e.id}"

    refute has_text?('CCAT')
    refute has_text?('Verify CDN Content')

    # And this is the reason why...
    assert has_text?('There are no CDN Repos defined')
  end

  test 'URLs become links in external message - list' do
    auth_as devel_user

    visit '/external_tests/list_all?test_type=ccat'

    (_, expected_url) = ccat_run_with_url_to_rt

    assert has_link?(expected_url, :href => expected_url)

    (_, expected_url) = ccat_run_with_url_to_jira

    assert has_link?(expected_url, :href => expected_url)
  end

  test 'URLs become links in external message - show' do
    auth_as devel_user

    (run, expected_url) = ccat_run_with_url_to_rt

    visit "/advisory/#{run.errata_id}/test_run/#{run.id}"

    assert has_link?(expected_url, :href => expected_url)

    (run, expected_url) = ccat_run_with_url_to_jira

    visit "/advisory/#{run.errata_id}/test_run/#{run.id}"

    assert has_link?(expected_url, :href => expected_url)
  end

  test 'list_all contains links to advisories' do
    auth_as devel_user

    visit '/external_tests/list_all?test_type=ccat'

    (_, expected_url) = ccat_run_with_url_to_advisory

    assert has_link?('a', :href => expected_url),
                     "Expected href #{expected_url} not found in: /external_tests/list_all?test_type=ccat"
    assert has_text?('RHSA-2012:0987'), "Cannot find expected text: RHSA-2012:0987"
  end

  test 'show ccat run does not contain extra links to advisory' do
    # When we are displaying runs on the CCAT tab of an advisory,
    # the table should not redundantly contain a link to the advisory.
    (run, expected_url) = ccat_run_with_url_to_advisory
    visit "/advisory/#{run.errata_id}/test_run/#{run.id}"
    assert has_no_link?('a', :href => expected_url),
                     "Unexpected #{expected_url} found in: /external_tests/list_all?test_type=ccat"
    assert has_no_text?('RHSA-2012:0987'), "Found unexpected text: RHSA-2012:0987"
  end

  def ccat_run_with_url_to_advisory
    run = ExternalTestRun.find(83)
    issue_url = "/advisory/#{run.errata.id}"
    [run, issue_url]
  end

  def ccat_run_with_url_to_rt
    run = ExternalTestRun.find(83)
    issue_url = 'https://engineering.redhat.com/rt/Ticket/Display.html?id=891234'
    assert_match issue_url, run.external_message
    [run, issue_url]
  end

  def ccat_run_with_url_to_jira
    run = ExternalTestRun.find(85)
    issue_url = 'https://projects.engineering.redhat.com/browse/ISSUE-891234'
    assert_match issue_url, run.external_message
    [run, issue_url]
  end
end
