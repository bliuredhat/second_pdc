When(/^(I )?click on '(.+)'$/) do |_, thing|
  click_on thing
end

Given(/^following builds to add:$/) do |builds|
  @builds = builds.symbolic_hashes
                  .each_with_object({}) do |build, o|
    type = symbolize(build[:type])
    o[type] ||= []
    o[type] << build[:name]
  end
end

Given(/^following variants:$/) do |variants|
  @listing_variants = variants.rows.flatten
end

Given(/^following product-versions to add builds:$/) do |pv_names|
  @product_versions = pv_names.rows.flatten
                              .map { |n| ProductVersion.find_by_name! n }
end

Given(/^mock brew service$/) do
  # RPC should happen during running the jobs, mock it now.
  # find the form which uses job tracker
  brew = MockedBrew.new
  brew.mock_builds(
    {
      good:      @builds[:good],
      nolisting: @builds[:no_listing],
      nonrpm:    @builds[:non_rpm],
      notexist:  @builds[:non_existing],
      bad:       @builds[:bad_format],
    },
    product_version_count: @product_versions.length,
    tags: [{ 'name' => 'rhevm-3.4-rhel-6-candidate' }],
    listing_variants: @listing_variants,

    # callback used when a product listing is generated; content
    # doesn't really matter beyond that it's the right shape and
    # the arches match what's returned for the mocked RPMs.
    valid_product_listing: lambda do |nvr|
      {
        'RHEV-Agents' => {
          nvr => { 'src' => %w(x86_64) }
        }
      }
    end
  )
end

When(/^I visit "Builds" tab$/) do
  visit "/advisory/#{@errata.id}/builds"
end

Then(/^progress bar should be hidden$/) do
  # progress bar elements should exist, but hidden
  all(:css, '.job_tracker_progressbar', visible: false).tap do |progress_bar|
    assert progress_bar.any?, 'Progress bar should be present but hidden'
    refute progress_bar.select(&:visible?).any?
  end
end

Then(/^builds form is shown$/) do
  @form = all('form').find { |f| f['job-tracker-action'].present? }
  assert_not_nil @form
  @job_tracker_action = @form['job-tracker-action']
end

Then(/^I add builds to product-versions$/) do
  # fill in the form with our desired builds.  We prepare a "params"
  # at the same time because javascript would normally serialize the
  # form for us, but that's not supported here.
  @params = {}

  all_builds = @builds.values.flatten.join("\n")
  within(@form) do
    @product_versions.each do |pv|
      field_id = "pv_#{pv.id}"
      fill_in field_id, with: all_builds
      @params[field_id] = all_builds
    end
  end
end

Then(/^job tracker count should change by (\d+)$/) do |count|
  # We don't support running JS, so we directly post the thing which
  # would have been posted asynchronously.
  # No brew RPC is expected to happen during this call.
  assert_difference('JobTracker.count', count) do
    post @job_tracker_action, @params
    assert_response :accepted, body
  end

  parsed = JSON.parse(response.body)
  assert parsed['job_tracker']['id']
  @tracker = JobTracker.find(parsed['job_tracker']['id'])

  # This hidden field would normally be filled by JS.
  # It's important for the real submit later.
  find('input#job_tracker_id', visible: false).set(@tracker.id)
end

Then(/^job runs$/) do
  with_no_logs_expected(Logger::Severity::ERROR) do
    @tracker.jobs.each do |j|
      j.run_with_lock(1.minute, 'test worker')
    end
  end

  @tracker.reload
  assert_equal 'FINISHED', @tracker.state
end

Then(/^build errors are shown$/) do
  # Now test that various builds were / weren't found.  This is an
  # important test as the errors were experienced by the background
  # jobs and not on the request which generated the current page, so
  # this tests that the errors were passed on in a meaningful way.
  within('#build_errors') do
    (@builds[:good] + @builds[:non_rpm]).each do |nvr|
      refute has_text?(nvr), "error text unexpectedly mentions #{nvr}"
    end
    (@builds[:non_existing] + @builds[:bad_format]).each do |nvr|
      assert has_text?("#{nvr}: Error retrieving build")
    end
  end
end

Then(/^warning about missing product listings is shown for following:$/) do |builds|
  # Should display a warning message about the missing product listings
  within('#no_product_listing_warning') do
    assert has_text?('Could not get product listings for the following Brew Builds.')

    within('#no_plc') do
      warnings = find('div').has_text?(builds.rows.flatten.join(' '))
      assert warnings, 'Unexpected missing product listings list.'
    end
  end
end

Then(/^each product version should have a warning badge$/) do
  # Each product version table should have a warning badge for python_cpopen
  all('table.buglist').each do |table|
    assert_not_nil(
      table.find('tr', text: 'Build python_cpopen-1.3-2.el6_5. Missing Product Listings'),
      "Could not find 'Missing product listing' badge."
    )
  end
end

When(/^I check all file types$/) do
  # On the last step, check every offered file type and save them
  all('.file_type_toggle').each do |input|
    input.set(true)
  end
  @old_mappings = @errata.reload.errata_brew_mappings.to_a
end

When(/^mappings are recomputed$/) do
  @new_mappings = @errata.reload.errata_brew_mappings.to_a
  @removed_mappings = @old_mappings - @new_mappings
  @added_mappings = @new_mappings - @old_mappings
end

Then(/^no mapping are removed$/) do
  # Note that no RPC is permitted at this step either (other than listTags)
  format_mapping = lambda do |m|
    "#{m.product_version.name}, #{m.brew_build.nvr}, #{m.brew_archive_type.try(:name) || 'rpm'}"
  end
  assert_equal [], @removed_mappings.map(&format_mapping).sort
end

Then(/^following mappings are added:$/) do |mappings|
  format_mapping = lambda do |m|
    "#{m.product_version.name}, #{m.brew_build.nvr}, #{m.brew_archive_type.try(:name) || 'rpm'}"
  end

  # The two typical builds and one non-rpm build should have been
  # successfully added to each of the three product versions.  The
  # other builds should have been ignored.  No RPC should have
  # happened at this step.
  expected_new_mappings = mappings.rows.flatten.sort
  assert_equal expected_new_mappings, @added_mappings.map(&format_mapping).sort
end
