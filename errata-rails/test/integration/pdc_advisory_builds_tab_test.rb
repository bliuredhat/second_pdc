require 'test_helper'
require 'test_helper/errata_view'

class PdcAdvisoryBuildTabTest < ActionDispatch::IntegrationTest
  include PdcAdvisoryUtils
  include ErrataDetailsView

  setup do
    auth_as devel_user
  end

  test 'builds tab list all pdc releases' do
    advisory = pdc_advisory('RHBA-2015:2399-17')

    active_releases = inactive_releases = nil
    VCR.use_cassette 'pdc_advisory_builds_tab_releases' do
      visit advisory_tab 'Builds', advisory: advisory
      active_releases, inactive_releases = pdc_releases_for_advisory(advisory)
    end

    # ensure there are active and inactive releases
    assert active_releases.count > 0, 'No active releases found for advisory'
    assert inactive_releases.count > 0, 'No inactive releases found for advisory'

    # active releases are listed
    expected_active_list = active_releases.map { |r| "#{r.short_name} - #{r.verbose_name}" }
    assert_array_equal expected_active_list.sort!, active_pdc_releases_displayed.sort!

    # A header for Inactive releases
    header = within_tab_content { find 'div.section_container > h2 > a' }
    assert_match /^Inactive Pdc Release/, header.text

    expected_inactive_list = inactive_releases.map{|vr| "#{vr.short_name} - #{vr.verbose_name}"}
    assert_array_equal expected_inactive_list.sort!, inactive_pdc_releases_displayed.sort!
  end


  test 'reload all builds' do
    e = pdc_advisory('RHBA-2015:2399-17')

    VCR.use_cassette 'pdc_advisory_reload_builds' do
      visit advisory_tab 'Builds', advisory: e
    end

    click_link 'Reload files for all builds'

    # Normally, we expect this to raise a confirmation dialog.
    # However, our web driver is not executing javascript, so,
    # the link activates directly.

    %r{/job_trackers/(?<tracker_id>\d+)$} =~ current_url
    assert_not_nil tracker_id
    tracker = JobTracker.find(tracker_id)

    assert_equal "Reload Builds for #{e.advisory_name}", tracker.name
    assert_equal 'RUNNING', tracker.state

    # make sure the expected jobs were created
    mapping_ids = tracker.jobs.map do |delayed_job|
      payload = delayed_job.payload_object
      assert payload.is_a?(BrewJobs::ReloadFilesJob), 'Not a ReloadFilesJob'
      payload.instance_variable_get('@mapping_id')
    end

    assert_equal e.pdc_errata_release_build_ids.sort, mapping_ids.sort
  end

  test 'build with mismatched brew flags' do
    # Add build with mismatched brew flags to a PDC advisory
    # Expected result: It would return errors:
    # <build>: does not have any of the valid tags: <valid-tags>. It only has the following tags: <tags>

    build = 'calamari-server-1.3.3-2.el7cp'
    tags = %w( ceph-1.3-rhel-7 ceph-1.3-rhel-7-candidate )
    valid_tags = %w(ceph-2-rhel-7-candidate ceph-2-rhel-7)

    brew = MockedBrew.new
    brew.mock_get_build(build)
    brew.mock_list_tags(build, tags)

    e = pdc_advisory('RHBA-2015:2399-17')

    VCR.insert_cassette 'pdc_advisory_builds_tag_mismatch'

    visit advisory_tab 'Builds', advisory: e
    params = fill_builds(pv_1: build)
    run_find_build_jobs(params)

    # ensure there aren't any errors already
    err_msg = "#{build}: does not have any of the valid tags: #{valid_tags.join(', ')}"
    refute page.has_content?(err_msg)

    # clicking the button should now show the error
    click_on('Find New Builds')
    assert page.has_content?(err_msg)

    VCR.eject_cassette
  end

  test 'non existing build' do
    # Add a non-existing build to a PDC advisory
    # Expected result: It would return errors:


    build = 'foobar-calamari-server-1.3.3-2.el7cp'
    brew = MockedBrew.new
    brew.mock_non_existing_builds(build)

    e = pdc_advisory('RHBA-2015:2399-17')

    VCR.insert_cassette 'pdc_advisory_builds_non_existing'

    visit advisory_tab 'Builds', advisory: e
    params = fill_builds(pv_1: build)
    run_find_build_jobs(params)

    # ensure there aren't any errors already
    err_msg = "#{build}: Error retrieving build #{build}: Couldn't find BrewBuild"
    refute page.has_content?(err_msg)

    # clicking the button should now show the expected error
    click_on('Find New Builds')
    assert page.has_content?(err_msg)

    VCR.eject_cassette

  end

  test 'add new build' do
    build = 'calamari-server-1.5.3-1.el7cp'
    valid_tags = %w(ceph-2-rhel-7-candidate ceph-2-rhel-7)

    e = pdc_advisory('RHBA-2017:24627-01')

    brew = MockedBrew.new
    brew.mock_list_tags(build, valid_tags)
    mock_pdc_product_listing('ceph-2.1-updates@rhel-7', build)


    VCR.insert_cassette 'pdc_advisory_builds_add_a_build'
    visit advisory_tab 'Builds', advisory: e

    params = fill_builds(pv_1: build)
    run_find_build_jobs(params)

    click_on('Find New Builds')

    new_builds = find('#eso-content form > table > caption > h2')
    assert_equal "ceph-2.1-updates@rhel-7 has new builds", new_builds.text

    click_on('Save Builds')

    header = find('#eso-content > div > h2:nth-child(4)')
    assert_equal 'Brew Builds Saved', header.text

    # should see the new build
    new_build_listed = first('#eso-content > div > h3 > a')
    assert_equal build, new_build_listed.text

    all_links = find_all('#eso-content > div > a').map(&:text)
    assert 'Remove this build from errata'.in?(all_links),
           'Failed to find "Remove this build from errata"'

    VCR.eject_cassette

  end

  test 'can not add older build than released packages' do
    VCR.insert_cassette 'pdc_advisory_builds_add_a_older_build'
    pdc_errata = Errata.find(21132)
    # release python-crypto-2.6.1-1.2.el7cp
    assert pdc_errata.brew_builds.map(&:nvr).include?('python-crypto-2.6.1-1.2.el7cp')
    PdcReleasedPackage.make_released_packages_for_errata(pdc_errata)

    # try to add python-crypto-2.6.1-1.1.el7cp
    older_nvr = 'python-crypto-2.6.1-1.1.el7cp'
    valid_tags = %w(ceph-2-rhel-7-candidate ceph-2-rhel-7)

    e = pdc_advisory('RHBA-2017:24627-01')

    brew = MockedBrew.new
    brew.mock_list_tags(older_nvr, valid_tags)
    mock_pdc_product_listing('ceph-2.1-updates@rhel-7', older_nvr)

    visit advisory_tab 'Builds', advisory: e

    params = fill_builds(pv_1: older_nvr)
    run_find_build_jobs(params)

    click_on('Find New Builds')

    new_builds = find('#eso-content form > table > caption > h2')
    assert_equal "ceph-2.1-updates@rhel-7 has new builds", new_builds.text

    click_on('Save Builds')
    error_string = "Unable to add build '#{older_nvr}'"

    assert_match /#{Regexp.escape(error_string)}.*has newer or equal version of/, page.body

    VCR.eject_cassette
  end

  private

  def  job_tracker_form
    all('form').find{ |f| f['job-tracker-action'].present? }
  end

  def fill_builds(opts)
    # fill in the form with our desired builds.  We prepare a "params"
    # at the same time because javascript would normally serialize the
    # form for us, but that's not supported here.

    params = {}

    # find the form which uses job tracker
    assert_not_nil job_tracker_form

    within(job_tracker_form) do
      opts.each do |release_version_id, builds|
        value = Array.wrap(builds).join("\n")
        fill_in(release_version_id, with:  value)
        params[release_version_id] = value
      end
    end
    params
  end

  def run_find_build_jobs(params)
    job_tracker_action = job_tracker_form['job-tracker-action']

    assert_difference('JobTracker.count', 1) do
      post job_tracker_action, params
      assert_response :accepted, response.body
    end

    parsed = JSON.parse(response.body)
    assert parsed['job_tracker']['id']
    tracker = JobTracker.find(parsed['job_tracker']['id'])

    # This hidden field would normally be filled by JS.
    # It's important for the real submit later.
    find('input#job_tracker_id', visible: false).set(tracker.id)

    with_no_logs_expected(Logger::Severity::ERROR) do
      tracker.jobs.each do |j|
        j.run_with_lock(1.minute, 'test worker')
      end
    end
    tracker.reload

    assert_equal 'FINISHED', tracker.state
  end


  def mock_pdc_product_listing(release, nvrs)
    pdc_release = PdcRelease.find_by_pdc_id(release)
    Array.wrap(nvrs).each do | nvr |
      brew_build = BrewBuild.find_by_nvr(nvr)

      PdcProductListing.
        expects(:fetch_live_listings).
        with(pdc_release, brew_build).
        returns(listings_data(brew_build.package.name))
    end
  end

  def listings_data(package_name)
    YAML.load(File.read(
      "#{Rails.root}/test/data/pdc_product_listing_cache/#{package_name}.yml"))
  end

end

# NOTE: copied from cucumber: features/local/support/brew.rb
#
# TODO: refactor the class out of this file so that it can be
# shared between multiple tests (cucumber integration test, and this)
class MockedBrew
  include Mocha::API # to use the mock method

  attr_reader :mocked_brew

  def initialize
    @mocked_brew = mock
    Brew.stubs(get_connection: Brew.get_connection)
    Brew.get_connection.instance_variable_set('@proxy', mocked_brew)
  end

  def mock_get_build(nvrs, opts = {})
    Array.wrap(nvrs).each do |nvr|
      nvr =~ /^(.*?)-([^-]+)-([^-]+)$/
      build_id = next_build_id
      mocked_brew
        .expects(:getBuild)
        .with(nvr).times(opts[:times] || 1)
        .returns(
          'nvr' => nvr, 'state' => 1,
          'version' => $2, 'release' => $3,
          'epoch' => 0, 'package_name' => $1,
          'id' => build_id
        )
      mocked_brew
        .expects(:listBuildRPMs).with(build_id).once
        .returns(
          [
            { 'id' => next_file_id, 'arch' => 'x86_64', 'nvr' => nvr },
            { 'id' => next_file_id, 'arch' => 'src', 'nvr' => nvr }
          ]
        )

      mocked_brew
        .expects(:listArchives)
        .with(build_id, nil, nil, nil, 'image').once
        .returns([])

      mocked_brew
        .expects(:listArchives)
        .with(build_id, nil, nil, nil, 'maven').once
        .returns([])

      mocked_brew
        .expects(:listArchives)
        .with(build_id, nil, nil, nil, 'win').once
        .returns([])
    end

  end

  def mock_non_existing_builds(nvrs, times: 1)
    Array.wrap(nvrs).each do |nvr|
      mocked_brew
        .expects(:getBuild).with(nvr)
        .times(times)
        .returns(nil)
    end
  end

  def mock_list_tags(nvr, tags)
    mocked_brew.expects(:listTags).with(nvr).at_least_once.tap do |exp|
      100.times do
        exp = exp.returns(tags.map { |t| { "name" => t } })
      end
    end
  end

  private

  def next_build_id
    @_build_id ||= BrewBuild.order('id DESC').limit(1).first.id + 100
    @_build_id += 1
  end

  def next_file_id
    @_file_id ||= BrewFile.order('id DESC').limit(1).first.id + 100
    @_file_id += 1
  end

end
