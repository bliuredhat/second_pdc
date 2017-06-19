require 'test_helper'

class ErrataBuildsTest < ActionDispatch::IntegrationTest

  setup do
    auth_as devel_user
  end

  test 'set buildroot-push flag' do
    e = Errata.find(11142)
    mapping = e.build_mappings.for_rpms.tap{|ms| assert_equal(1, ms.length)}.first

    # force this feature enabled for this product version
    mapping.release_version.tap{ |rv| rv.allow_buildroot_push = true }.save!

    # check that buildroot-push links are not visible to devel
    visit "/advisory/#{e.id}/builds"
    verify_no_buildroot_links

    # revisit as qa_user and proceed
    auth_as qa_user
    visit "/advisory/#{e.id}/builds"

    verify_buildroot_push(mapping, false)
    click_link 'Request Push to Buildroot'
    verify_buildroot_push(mapping, true)
  end

  test 'unset buildroot-push flag' do
    e = Errata.find(16409)
    mapping = e.build_mappings.for_rpms.tap{|ms| assert_equal(1, ms.length)}.first
    # force this feature enabled for this product version
    mapping.release_version.tap{ |rv| rv.allow_buildroot_push = true }.save!

    # admin, qa, or releng should be allowed to unset the flag; not devel.
    visit "/advisory/#{e.id}/builds"
    verify_no_buildroot_links

    auth_as releng_user
    visit "/advisory/#{e.id}/builds"

    verify_buildroot_push(mapping, true)
    click_link 'Cancel Push to Buildroot'
    verify_buildroot_push(mapping, false)
  end

  test 'buildroot-push is toggled in product version' do
    e = Errata.find(20292)

    assert_equal 1, e.build_mappings.length
    rv = e.build_mappings.first.release_version

    # This is a RHEL-7-JBEAP-6 mapping; currently, it is not expected that
    # buildroot-push is allowed in this product version
    # Ensure that user has privs to see the link if it's presented.
    auth_as releng_user
    visit "/advisory/#{e.id}/builds"
    refute has_link?('Request Push to Buildroot')

    # RCM enables it in admin UI... auth'd as releng_user.
    visit "/product_versions/#{rv.id}/edit"
    allow_buildroot_push_checkbox.tap do |cb|
      refute cb.checked?
      cb.set(true)
    end
    click_on 'Update'

    assert rv.reload.allow_buildroot_push?

    # Now it should be possible for QA to use the feature
    auth_as qa_user
    visit "/advisory/#{e.id}/builds"
    assert has_link?('Request Push to Buildroot')
  end

  def allow_buildroot_push_checkbox
    find(:xpath, '//td[contains(text(), "Allow Buildroot Push?")]/following-sibling::td//input[@type="checkbox"]')
  end

  def verify_no_buildroot_links
    %w{Cancel Request}.each do |w|
      refute has_link?("#{w} Push to Buildroot")
    end
  end

  def verify_buildroot_push(mapping, expected)
    assert_equal expected,  mapping.reload.flags.include?('buildroot-push')
    assert_equal expected,  has_content?('buildroot-push')
    assert_equal expected,  has_link?('Cancel Push to Buildroot')
    assert_equal !expected, has_link?('Request Push to Buildroot')
  end

  test 'reload all builds' do
    e = Errata.find(7519)
    visit "/advisory/#{e.id}/builds"
    click_link 'Reload files for all builds'

    # Normally, we expect this to raise a confirmation dialog.
    # However, our web driver is not executing javascript, so the link activates directly.

    pattern = %r{/job_trackers/(\d+)$}
    assert_match pattern, current_url
    current_url =~ pattern
    tracker = JobTracker.find($1.to_i)

    assert_equal "Reload Builds for #{e.advisory_name}", tracker.name
    assert_equal 'RUNNING', tracker.state

    # make sure the expected jobs were created
    mapping_ids = tracker.jobs.map do |dj|
      obj = dj.payload_object
      assert obj.kind_of?(BrewJobs::ReloadFilesJob)
      obj.instance_variable_get('@mapping_id')
    end

    build_mapping_ids = e.build_mappings.select(:id).pluck(:id)
    assert_equal build_mapping_ids.sort, mapping_ids.sort
  end

  test 'find and save builds with progress bar' do
    e = Errata.find(16409)

    e.change_state!('NEW_FILES', @devel)

    builds = [
      good_builds = %w[
        mom-0.4.0-1.el6ev
        org.ovirt.engine-jboss-modules-maven-plugin-1.0-2
      ],
      nolisting_builds = %w[python_cpopen-1.3-2.el6_5],
      nonrpm_builds = %w[rhev-spice-guest-msi-4.11-1],
      notexist_builds = %w[notexist-bla-1.2.3],
      bad_builds = %w[bad-format],
    ].flatten

    # variants which will be called for product listings
    listing_variants = %w[
      RHEL-6-Workstation-RHEV
      RHEL-6-ComputeNode-RHEV
      RHEL-6-Client-RHEV
      RHEL-6-Server-RHEV
      RHEL-6-Server-RHEV-S-3.3
      RHEL-6-Server-RHEV-S-3.4
   ]

    visit "/advisory/#{e.id}/builds"

    # progress bar elements should exist, but hidden
    all(:css, '.job_tracker_progressbar', visible: false).tap do |progress|
      assert progress.any?
      refute progress.select(&:visible?).any?
    end

    # find the form which uses job tracker
    form = all('form').find{|f| f['job-tracker-action'].present?}
    assert_not_nil form
    job_tracker_action = form['job-tracker-action']

    # fill in the form with our desired builds.  We prepare a "params"
    # at the same time because javascript would normally serialize the
    # form for us, but that's not supported here.
    params = {}
    within(form) do
      %w[pv_153 pv_269 pv_318].each do |pv|
        fill_in(pv, :with => builds.join("\n"))
        params[pv] = builds.join("\n")
      end
    end

    brew = mock_brew_proxy

    # We don't support running JS, so we directly post the thing which
    # would have been posted asynchronously.
    # No brew RPC is expected to happen during this call.
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

    # RPC should happen during running the jobs, mock it now.
    brew_mock_builds(brew,
      {
        :good => good_builds,
        :nolisting => nolisting_builds,
        :nonrpm => nonrpm_builds,
        :notexist => notexist_builds,
        :bad => bad_builds,
      },
      :product_version_count => 3,
      :tags => [{'name' => 'rhevm-3.4-rhel-6-candidate'}],
      :listing_variants => listing_variants,

      # callback used when a product listing is generated; content
      # doesn't really matter beyond that it's the right shape and
      # the arches match what's returned for the mocked RPMs.
      :valid_product_listing => lambda{|nvr| {'RHEV-Agents' => {nvr => {'src' => %w[x86_64]}}}}
    )

    with_no_logs_expected(Logger::Severity::ERROR) do
      tracker.jobs.each do |j|
        j.run_with_lock(1.minute, 'test worker')
      end
    end

    tracker.reload
    assert_equal 'FINISHED', tracker.state

    # Now submit the form as usual.
    # During this step, builds or product listings should not be imported.
    brew_mock_no_rpc(brew)
    click_on('Find New Builds')

    # Now test that various builds were / weren't found.  This is an
    # important test as the errors were experienced by the background
    # jobs and not on the request which generated the current page, so
    # this tests that the errors were passed on in a meaningful way.
    within("#build_errors") do
      (good_builds + nonrpm_builds).each do |nvr|
        refute has_text?(nvr), "error text unexpectedly mentions #{nvr}"
      end
      (notexist_builds + bad_builds).each do |nvr|
        assert has_text?("#{nvr}: Error retrieving build")
      end
    end

    # Should display a warning message about the missing product listings
    within("#no_product_listing_warning") do
      assert has_text?("Could not get product listings for the following Brew Builds.")
      within("#no_plc") do
        assert(find("div").has_text?(
          ['RHEL-6-RHEV python_cpopen-1.3-2.el6_5',
           'RHEL-6-RHEV-S-3.3 python_cpopen-1.3-2.el6_5',
           'RHEL-6-RHEV-S-3.4 python_cpopen-1.3-2.el6_5',
          ].join(" ")),
          "Unexpected missing product listings list."
        )
      end
    end

    # Each product version table should have a warning badge for python_cpopen
    all("table.buglist").each do |table|
      assert_not_nil(
        table.find("tr", :text => 'Build python_cpopen-1.3-2.el6_5. Missing Product Listings'),
        "Could not find 'Missing product listing' badge."
      )
    end

    # On the last step, check every offered file type and save them
    all('.file_type_toggle').each do |input|
      input.set(true)
    end

    # Note that no RPC is permitted at this step either (other than listTags)

    old_mappings = e.reload.build_mappings.to_a
    click_on 'Save Builds'
    new_mappings = e.reload.build_mappings.to_a

    format_mapping = lambda{|m|
      "#{m.product_version.name}, #{m.brew_build.nvr}, #{m.brew_archive_type.try(:name) || 'rpm'}"
    }

    removed_mappings = old_mappings - new_mappings
    assert_equal [], removed_mappings.map(&format_mapping).sort

    added_mappings = new_mappings - old_mappings
    # The two typical builds and one non-rpm build should have been
    # successfully added to each of the three product versions.  The
    # other builds should have been ignored.  No RPC should have
    # happened at this step.
    assert_equal( <<-'eos'.split("\n").reject(&:blank?), added_mappings.map(&format_mapping).sort )
RHEL-6-RHEV, mom-0.4.0-1.el6ev, rpm
RHEL-6-RHEV, org.ovirt.engine-jboss-modules-maven-plugin-1.0-2, rpm
RHEL-6-RHEV, python_cpopen-1.3-2.el6_5, rpm
RHEL-6-RHEV, rhev-spice-guest-msi-4.11-1, tar
RHEL-6-RHEV-S-3.3, mom-0.4.0-1.el6ev, rpm
RHEL-6-RHEV-S-3.3, org.ovirt.engine-jboss-modules-maven-plugin-1.0-2, rpm
RHEL-6-RHEV-S-3.3, python_cpopen-1.3-2.el6_5, rpm
RHEL-6-RHEV-S-3.3, rhev-spice-guest-msi-4.11-1, tar
RHEL-6-RHEV-S-3.4, mom-0.4.0-1.el6ev, rpm
RHEL-6-RHEV-S-3.4, org.ovirt.engine-jboss-modules-maven-plugin-1.0-2, rpm
RHEL-6-RHEV-S-3.4, python_cpopen-1.3-2.el6_5, rpm
RHEL-6-RHEV-S-3.4, rhev-spice-guest-msi-4.11-1, tar
eos
  end

  def ppc64le_build_pair_test(args)
    # all builds for the test must already be in fixtures.
    # (but tags can't be stored in fixtures, just pretend they're always OK...)
    Brew.any_instance.stubs(:getBuild).raises('SIMULATED BREW ERROR')
    Brew.any_instance.stubs(:build_is_properly_tagged? => true)

    # Is the aarch64 relation enabled?
    Settings.stubs(:aarch64_build_pair_enabled).returns(args[:aarch64_build_pair_enabled])

    e = Errata.find(19401)
    assert_equal 0, e.brew_builds.count, 'fixture problem: advisory expected to start with no builds'

    visit "/advisory/#{e.id}/builds"

    pv = ProductVersion.find_by_name!('RHEL-7.1.Z')
    pv_le = ProductVersion.find_by_name!('RHEL-LE-7.1.Z')
    pv_aa = ProductVersion.find_by_name!('RHELSA-7.1.Z')

    # advisory should accept builds for these three
    assert find(:css, 'div.eso-tab-content form').has_text? pv.name
    assert find(:css, 'div.eso-tab-content form').has_text? pv_le.name
    assert find(:css, 'div.eso-tab-content form').has_text? pv_aa.name

    builds = args[:input_builds] || []
    builds_le = args[:input_builds_le] || []
    builds_aa = args[:input_builds_aa] || []

    [[pv,builds], [pv_le,builds_le], [pv_aa,builds_aa]].each do |this_pv,this_builds|
      next unless this_builds.any?
      fill_in "pv_#{this_pv.id}", :with => this_builds.join("\n")
    end

    click_on 'Find New Builds'

    if fn = args[:on_preview_files]
      fn.call()
    end

    expected_builds = args[:expected_builds] || []
    expected_builds_le = args[:expected_builds_le] || []
    expected_builds_aa = args[:expected_builds_aa] || []

    assert_difference('ErrataBrewMapping.count', expected_builds.length + expected_builds_le.length + expected_builds_aa.length) do
      click_on 'Save Builds'
    end

    expected_mappings = [[pv.name,expected_builds], [pv_le.name,expected_builds_le], [pv_aa.name,expected_builds_aa]].
      map{|pv_name,builds| builds.sort.map{|nvr| "#{pv_name} - #{nvr}"}}.
      inject(&:+)

    assert_equal expected_mappings, e.reload.build_mappings.
        map{|m| "#{m.product_version.name} - #{m.brew_build.nvr}"}.sort

    e
  end

  def assert_shows_build_pair_info(errata, *for_slugs)
    # When the recommended ppc64le aarch64 builds are present, the builds page
    # displays some info (not a warning).
    visit "/advisory/#{errata.id}/builds"

    for_slugs.each do |slug|
      assert has_text?("This advisory includes #{slug} builds.")
      assert has_text?("In most cases, non-#{slug} builds in")
    end
  end

  def assert_shows_extra_build_found_info(slug, pv_name, nvr, extra_nvr)
    assert has_text?('Errata Tool has automatically added some related builds to the builds list'), page.html
    assert has_text?("#{pv_name} has new builds"), page.html
    assert has_text?("#{extra_nvr} - #{slug} counterpart of #{nvr}"), page.html
    assert has_text?("In most cases, non-#{slug} builds in")
  end

  test 'PPC64LE builds are automatically selected for RHEL 7.1 errata' do
    sssd_nvr, sssd_nvr_le = %w[ sssd-1.12.2-58.el7 sssd-1.12.2-58.ael7b ]
    tzdata_nvr, tzdata_nvr_le = %w[ tzdata-2015a-1.el7 tzdata-2015a-1.ael7b ]

    errata = ppc64le_build_pair_test(
      :input_builds => [sssd_nvr, tzdata_nvr],
      :expected_builds => [sssd_nvr, tzdata_nvr],
      :expected_builds_le => [sssd_nvr_le, tzdata_nvr_le],
      :on_preview_files => lambda{
        assert_shows_extra_build_found_info('ppc64le', 'RHEL-LE-7.1.Z', sssd_nvr, sssd_nvr_le)
        assert_shows_extra_build_found_info('ppc64le', 'RHEL-LE-7.1.Z', tzdata_nvr, tzdata_nvr_le)
      })

    assert_shows_build_pair_info(errata, 'ppc64le')
  end

  test 'Both PPC64LE and ARM64 builds are automatically selected for RHEL 7.1 errata' do
    rsh_nvr, rsh_nvr_le, rsh_nvr_aa = %w[ rsh-0.17-76.el7_1.1 rsh-0.17-76.ael7b_1.1 rsh-0.17-76.aa7a_1.1 ]

    errata = ppc64le_build_pair_test(
      :aarch64_build_pair_enabled => true,
      :input_builds => [rsh_nvr],
      :expected_builds => [rsh_nvr],
      :expected_builds_le => [rsh_nvr_le],
      :expected_builds_aa => [rsh_nvr_aa],
      :on_preview_files => lambda{
        assert_shows_extra_build_found_info('ppc64le', 'RHEL-LE-7.1.Z', rsh_nvr, rsh_nvr_le)
        assert_shows_extra_build_found_info('aarch64', 'RHELSA-7.1.Z', rsh_nvr, rsh_nvr_aa)
      })

    assert_shows_build_pair_info(errata, 'ppc64le', 'aarch64')
  end

  test 'explicitly including PPC64LE builds works as normal' do
    # in this test case, user manually inputs both builds in the build
    # pair, and there's no visible special behavior from ET.
    ppc64le_build_pair_test(
      :input_builds => %w[sssd-1.12.2-58.el7],
      :input_builds_le => %w[sssd-1.12.2-58.ael7b],
      :expected_builds => %w[sssd-1.12.2-58.el7],
      :expected_builds_le => %w[sssd-1.12.2-58.ael7b],
      :on_preview_files => lambda{
        refute has_text?('Errata Tool has automatically added some related builds to the builds list'), page.html
        assert has_text?('RHEL-7.1.Z has new builds'), page.html
        assert has_text?('RHEL-LE-7.1.Z has new builds'), page.html
      })
  end

  test 'warns if some PPC64LE builds are not found' do
    # In this test, the PPC64LE variant of the iscsi-initiator-utils
    # build can't be found.  ET warns, but the user can proceed and
    # save all the other builds.
    ppc64le_build_pair_test(
      :input_builds => %w[sssd-1.12.2-58.el7 iscsi-initiator-utils-6.2.0.873-29.el7],
      :expected_builds => %w[sssd-1.12.2-58.el7 iscsi-initiator-utils-6.2.0.873-29.el7],
      :expected_builds_le => %w[sssd-1.12.2-58.ael7b],
      :on_preview_files => lambda{
        assert has_text?('Error retrieving build iscsi-initiator-utils-6.2.0.873-29.ael7b: SIMULATED BREW ERROR'), page.html
        assert has_text?('Errata Tool has automatically added some related builds to the builds list. However, some related builds could not be fetched.'), page.html
        assert has_text?('RHEL-7.1.Z has new builds'), page.html
        assert has_text?('RHEL-LE-7.1.Z has new builds'), page.html
      })

    # The "builds saved" page should also repeat a warning about missing builds.
    within('.infobox.alert_icon') do
      assert has_text?('WARNING: This advisory may be missing some builds')
      assert has_text?('Missing ppc64le builds for RHEL-LE-7.1.Z:')
      assert has_text?('iscsi-initiator-utils-6.2.0.873-29.ael7b')
    end
  end

  test 'visiting builds page warns when PPC64LE builds are missing' do
    # Ensure this setting is used correctly when generating the warning.
    # In particular, HTML shouldn't end up escaped.
    Settings.ppc64le_build_pair_explanation = <<-'eos'
Due to <b>reasons</b>, you should add some ppc64le builds.

See <a href="https://bugzilla.redhat.com/show_bug.cgi?id=1188483">
this bug</a> for more information.
eos

    visit '/advisory/19829/builds'

    within('.infobox.alert_icon') do
      assert has_text?('WARNING: This advisory may be missing some builds')
      assert has_text?('Missing ppc64le builds for RHEL-LE-7.1.Z:')
      assert has_text?('basesystem-10.0-6.ael7b')
      assert has_text?('coreutils-8.15-2.ael7b')
      assert has_text?('Due to reasons, you should add some ppc64le builds')
      assert has_link?('this bug', :href => 'https://bugzilla.redhat.com/show_bug.cgi?id=1188483')
    end
  end

  test 'product listings RPM mismatches shown' do
    e = Errata.find(22508)
    expected_rpm_count = 6

    map = e.build_mappings.first
    rpms = map.rpm_files_not_in_listings
    assert_equal expected_rpm_count, rpms.count

    visit "/advisory/#{e.id}/builds"
    assert has_text? "Brew Build #{map.brew_build.nvr}"
    assert has_text? "#{expected_rpm_count} Build RPMs not in Product Listings"
    refute has_link? 'Dismiss'

    # admin or releng should be allowed to ack the mismatches
    auth_as releng_user
    visit "/advisory/#{e.id}/builds"
    assert has_text? "Brew Build #{map.brew_build.nvr}"
    assert has_text? "#{expected_rpm_count} Build RPMs not in Product Listings"
    assert has_link? 'Dismiss'
    click_link 'Dismiss'

    # the mismatches are no longer shown
    visit "/advisory/#{e.id}/builds"
    assert has_text? "Brew Build #{map.brew_build.nvr}"
    refute has_text? "#{expected_rpm_count} Build RPMs not in Product Listings"
    refute has_link? 'Dismiss'
  end

  # Mock brew to verify when certain RPC calls happen.  Do it by
  # using a real Brew client, but hacking the XMLRPC @proxy to a
  # mock.  This way we are mocking the RPC only and not the non-RPC
  # logic also present on that class.
  def mock_brew_proxy
    Brew.stubs(:get_connection => Brew.get_connection)
    brew = mock()
    Brew.get_connection.instance_variable_set('@proxy', brew)
    brew
  end

  def next_mock_build_id
    @_build_id ||= BrewBuild.order('id DESC').limit(1).first.id + 100
    @_build_id = @_build_id + 1
  end

  def next_mock_file_id
    @_file_id ||= BrewFile.order('id DESC').limit(1).first.id + 100
    @_file_id = @_file_id + 1
  end

  def brew_mock_exist_builds(brew, nvrs, opts={})
    nvrs.each do |nvr|
      nvr =~ /^(.*?)-([^-]+)-([^-]+)$/
      build_id = next_mock_build_id
      file_id = next_mock_file_id
      brew.expects(:getBuild).with(nvr).times(opts[:times]||1).returns(
        {'nvr' => nvr, 'state' => 1, 'version' => $2, 'release' => $3, 'epoch' => 0, 'package_name' => $1, 'id' => build_id})

      if opts[:nonrpm]
        brew.expects(:listArchives).with(build_id, nil, nil, nil, 'image').once.returns([
          {'id' => file_id, 'type_id' => BrewArchiveType.find_by_name!('tar').id, 'arch' => 'x86_64', 'filename' => 'some-file.tar'},
        ])
        brew.expects(:listBuildRPMs).with(build_id).once.returns([])
      else
        brew.expects(:listArchives).with(build_id, nil, nil, nil, 'image').once.returns([])
        next_file_id = next_mock_file_id
        brew.expects(:listBuildRPMs).with(build_id).once.returns([
          {'id' => file_id, 'arch' => 'x86_64', 'nvr' => nvr},
          {'id' => next_file_id, 'arch' => 'src', 'nvr' => nvr},
        ])
      end
      brew.expects(:listArchives).with(build_id, nil, nil, nil, 'win').once.returns([])
      brew.expects(:listArchives).with(build_id, nil, nil, nil, 'maven').once.returns([])

      (opts[:product_listings]||[]).each do |(variant,generator)|
        value = generator.call(nvr)
        expect = brew.expects(:getProductListings).with(variant, build_id)
        if value.kind_of?(Exception)
          expect.raises(value)
          # when raising an exception on split product listings, our
          # client bails out on the first problem.  However, the order
          # in which product listings are queried is undefined, so we
          # can't tell which call to expect.  So weaken the test in
          # this case.
          expect.at_least(0)
        else
          expect.at_least_once.returns(value)
        end
      end
    end
  end

  def brew_mock_notexist_builds(brew, nvrs, opts={})
    nvrs.each do |nvr|
      brew.expects(:getBuild).with(nvr).times(opts[:times]||1).returns(nil)
    end
  end

  def brew_mock_bad_builds(brew, nvrs, opts={})
    nvrs.each do |nvr|
      brew.expects(:getBuild).with(nvr).times(opts[:times]||1).raises(XMLRPC::FaultException.new(1000, "invalid format: #{nvr}"))
    end
  end

  def brew_mock_builds(brew, builds, opts={})
    brew_mock_exist_builds(brew, builds[:good], :product_listings => opts[:listing_variants].map{|v|
      [v, opts[:valid_product_listing]]
    })

    brew_mock_exist_builds(brew, builds[:nolisting], :product_listings => opts[:listing_variants].map{|v|
      # These builds can successfully fetch product listings, but they're empty
      [v, lambda{|nvr| {}}]
    })

    brew_mock_exist_builds(brew, builds[:nonrpm], :nonrpm => true, :product_listings => opts[:listing_variants].map{|v|
      # These builds don't have SRPMs and therefore crash on getProductListings
      [v, lambda{|nvr| XMLRPC::FaultException.new(1000, "Could not find any RPMs for build #{nvr}")}]
    })

    brew_mock_notexist_builds(brew, builds[:notexist], :times => opts[:product_version_count])
    brew_mock_bad_builds(brew, builds[:bad], :times => opts[:product_version_count])

    # for listTags we use a simple mock which just returns a valid tag
    # for this advisory, for any build.
    brew.expects(:listTags).at_least_once.tap do |exp|
      # Would like to return a new copy indefinitely, but I can't see
      # a way to do it in the mocha API, so just do it a lot of times
      100.times do
        # some code does in-place modification of this array, so we need
        # to mock a copy each time.
        exp = exp.returns(opts[:tags].dup)
      end
    end
  end

  def brew_mock_no_rpc(brew)
    brew.expects(:getBuild).never
    brew.expects(:listBuildRPMs).never
    # listTags remains permitted (see Bug 1167143).
  end
end

class ErrataBuildsNonRpmTest < ActionDispatch::IntegrationTest

  def build_table_xpath(pv, nvr)
    "(//h2[text()='Builds for #{pv}']/following::h3//*[contains(text(), '#{nvr}')]/following::table)[1]"
  end

  test 'can add non-rpm files and display correctly' do
    Brew.any_instance.stubs(:build_is_properly_tagged? => true)
    ProductListing.stubs(:get_brew_product_listings => {})

    auth_as devel_user

    e = Errata.find(16396)

    bb = BrewBuild.find_by_nvr!('spice-client-msi-3.4-4')

    visit "/advisory/#{e.id}/builds"
    page.all('textarea').each{|n| n.set('spice-client-msi-3.4-4')}

    click_button 'Find New Builds'

    assert has_content?('Multiple content types were found'), page.html

    # Note: not testing the global <-> per-build file type relationship,
    # depends on javascript!

    ['RHEL-7', 'RHEL-7.0-Supplementary'].each do |pv|
      assert has_content?("#{pv} has new builds"), page.html
    end

    [
      ['RHEL-7', 'RPM', false],
      ['RHEL-7', 'cab', true],
      ['RHEL-7', 'zip', true],
      ['RHEL-7.0-Supplementary', 'RPM', false],
      ['RHEL-7.0-Supplementary', 'zip', true],
      ['RHEL-7.0-Supplementary', 'txt', true],
    ].each do |pv, type, checked|
      within_table("#{pv} has new builds") do
        within('thead td', :text => type) do
          self.send(checked ? :check : :uncheck, 'Include in advisory?')
        end
      end
    end

    click_button 'Save Builds'

    assert page.has_content?('Brew Builds Saved')

    # test that certain files are displayed in the right tables.
    docker_ks_file = '/mnt/redhat/brewroot/packages/rhel-server-docker/7.0/22/images/rhel-7-server-docker.ks'
    spice_cab_file = '/mnt/redhat/brewroot/packages/spice-client-msi/3.4/4/win/SpiceX_x64.cab'
    spice_txt_file = '/mnt/redhat/brewroot/packages/spice-client-msi/3.4/4/win/SpiceVersion.txt'
    spice_zip_file = '/mnt/redhat/brewroot/packages/spice-client-msi/3.4/4/win/spice-client-msi-3.4-4-spec.zip'

    # test that this file (which was already on the advisory) is still on the page,
    # but not in the tables for the spice build
    assert has_content?(docker_ks_file)

    # selector for arch/type cells within a table; should be the first
    # td in each row, excluding header rows (hence the bz_even/bz_odd
    # to only catch "normal" rows)
    arch_type_td = 'tr.bz_even td:first-child, tr.bz_odd td:first-child'

    within(:xpath, build_table_xpath('RHEL-7', bb.nvr)) do
      refute has_content?(docker_ks_file), html
      assert has_content?(spice_cab_file), html
      assert has_content?(spice_zip_file), html
      refute has_content?(spice_txt_file), html

      # Verify displayed arch/type values (the first column).
      # These non-RPM files have no arch.
      assert_equal %w[cab zip], all(arch_type_td).map(&:text).uniq
    end

    within(:xpath, build_table_xpath('RHEL-7.0-Supplementary', bb.nvr)) do
      refute has_content?(docker_ks_file), html
      refute has_content?(spice_cab_file), html
      assert has_content?(spice_zip_file), html
      assert has_content?(spice_txt_file), html
    end

    # The existing rhel-server-docker-7.0-22 should still exist, with
    # no modifications
    within(:xpath, build_table_xpath('RHEL-7.0-Supplementary', 'rhel-server-docker-7.0-22')) do
      assert has_content?(docker_ks_file), html
      refute has_content?(spice_cab_file), html
      refute has_content?(spice_zip_file), html
      refute has_content?(spice_txt_file), html

      # Verify displayed arch/type values.
      # These non-RPM files have an arch, unlike the spice files
      assert_equal [
        'SRPMS',
        'noarch',
        'ks (x86_64)',
        'tar (x86_64)',
      ], all(arch_type_td).map(&:text).uniq
    end
  end

  test "reselect file types" do
    auth_as devel_user

    e = Errata.find(16396)
    rpm_and_nonrpm_mapping = ErrataBrewMapping.find(55968)

    # make the build acceptable for this advisory
    brew_tag = BrewTag.find_or_create_by_name('guest-rhel-7.0-candidate')
    e.release.brew_tags << brew_tag

    visit "/advisory/#{e.id}/builds"

    old_content_types = e.generate_content_types
    assert_equal %w(ks rpm tar), old_content_types

    click_link 'Reselect file types'

    assert has_content?('Multiple content types were found'), page.html
    [
    'RPM', 'ks', 'tar','xml'
    ].each do |type|
      within('thead td', :text => type) do
        all('input[type=checkbox]').each do |checkbox|
          if type == 'xml'
            refute checkbox.checked?
          else
            assert checkbox.checked?
          end
        end
      end
    end

    [
      ['RPM', false],
      ['ks', true],
      ['tar', true],
      ['xml', true]
    ].each do |type, checked|
      within('thead td', :text => type) do
        self.send(checked ? :check : :uncheck, 'Include in advisory?')
      end
    end

    click_button 'Save Reselect Build'

    assert page.has_content?('Brew Builds Saved')

    update_content_types = e.reload.content_types
    assert_equal %w(ks tar xml), update_content_types
  end

  test 'inactive product versions shown in build screen' do
    auth_as devel_user

    e = Errata.find(16654)
    assert e.available_product_versions.count > 2

    visit "/advisory/#{e.id}/builds"
    refute page.has_content?('Builds may not be added for the following inactive')

    e.available_product_versions.last(2).each do |pv|
      pv.enabled = false
      pv.save!
    end

    visit "/advisory/#{e.id}/builds"
    assert page.has_content?('Builds may not be added for the following inactive')
  end

  test 'adding docker build disallows selection of non-image files' do
    Brew.any_instance.stubs(:build_is_properly_tagged? => true)
    ProductListing.stubs(:get_brew_product_listings => {})

    auth_as devel_user

    e = Errata.find(21101)

    # Remove existing builds so they can be added again
    e.build_mappings.each(&:obsolete!)

    nvr = 'rhel-server-docker-6.8-25'
    bb = BrewBuild.find_by_nvr!(nvr)

    visit "/advisory/#{e.id}/builds"

    fill_in('pv_149', :with => nvr)
    click_button 'Find New Builds'

    ['ks', 'xml'].each do |type|
      within('thead td', :text => type) do
        assert_equal 'Cannot include in advisory', find('label').text
      end
    end

    within('thead td', :text => 'tar [Docker]') do
      assert_equal 'Include in advisory?', find('label').text
      assert find('input[type=checkbox]').checked?
    end

  end
end
