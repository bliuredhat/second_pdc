require 'test_helper'

class PackageRestrictionFormTest < ActionDispatch::IntegrationTest
  setup do
    auth_as admin_user
    @restriction = PackageRestriction.first
    @package = @restriction.package
    @variant = @restriction.variant
    @cdn = PushTarget.find_by_name('cdn')
    @rhn_live = PushTarget.find_by_name('rhn_live')
    @table_title = "Depending active errata with locked filelist"
    @noresult_title = "No #{@table_title.downcase}."
    @table_note = "NOTE: User is not allowed to amend the restriction if the package has active"\
      " errata with locked filelist."
  end

  def create_errata(build)
    errata = create_test_rhba("RHEL-7.0.0", build.nvr)
    pass_rpmdiff_runs(errata)
    errata.change_state!(State::QE, qa_user)
    errata
  end

  def assert_preconditions(expected_errata_count)
    errata = @restriction.active_errata
    assert_equal(
      expected_errata_count,
      errata.count,
      "Fixture problem: The active errata list is no longer empty."
    )
    # ensure the variant supports cdn
    assert(
      @variant.supported_push_types.include?(@cdn.push_type),
      "Fixture problem: #{@variant.name} needs to support #{@cdn.push_type}."
    )
    # ensure the package is not pushing to cdn
    refute(
      @restriction.supported_push_types.include?(@cdn.push_type),
      "Fixture problem: Package shouldn't support #{@cdn.push_type}."
    )
    return errata
  end

  def assert_notice(package, variant, push_targets)
    actual_message = page.find('#flash_notice').text
    expected_message =
      "Package '#{package.name}' for variant '#{variant.name}' is set"\
      " to push to #{push_targets.map(&:name).join(', ')} now."
    assert_match(/#{Regexp.escape(expected_message)}/, actual_message)
  end

  def assert_active_errata_error
    actual_message = page.find('#flash_error').text
    expected_message =
      'Validation failed: Add/Update/Delete restriction rule for package that has active'\
      ' advisories with locked filelist is not allowed. To amend the rule, please make sure'\
      " all depending active advisories are either inactive or in unlocked state."
    assert_match(/#{Regexp.escape(expected_message)}/, actual_message)
  end

  test "edit package restriction with depending active errata" do
    # create 5 depending errata
    number = 5
    number.times { create_errata(@package.brew_builds.first) }
    errata = assert_preconditions(number)

    visit "/variants/#{@variant.id}/package_restrictions/#{@restriction.id}/edit"
    assert_active_errata_table(errata, @table_title, @table_note)

    select @cdn.name, :from => "package_restriction_push_targets"
    click_on 'Save'

    assert_active_errata_error
  end

  test "edit package restriction without depending active errata" do
    errata = assert_preconditions(0)
    original = @restriction.push_targets.to_a

    visit "/variants/#{@variant.id}/package_restrictions/#{@restriction.id}/edit"
    assert_active_errata_table(errata, @noresult_title)

    select @cdn.name, :from => "package_restriction_push_targets"
    click_on 'Save'

    @restriction.reload
    assert_notice(@package, @variant, original.concat([@cdn]))
  end

  test "edit package restriction with more than 20 active errata" do
    # fake 30 depend active errata
    errata = Errata.limit(30).to_a
    PackageRestriction.any_instance.stubs(:active_errata).returns(errata)

    visit "/variants/#{@variant.id}/package_restrictions/#{@restriction.id}/edit"
    assert_active_errata_table(errata, @table_title, @table_note)
  end

  test "add package restriction" do
    @restriction.destroy
    assert_difference('PackageRestriction.count', 1) do
      visit "/variants/#{@variant.id}/package_restrictions/new"
      fill_in 'package_restriction_package', :with => @package.name
      select @cdn.name, :from => "package_restriction_push_targets"
      select @rhn_live.name, :from => "package_restriction_push_targets"
      click_on 'Save'
    end
    assert_notice(@package, @variant, [@rhn_live, @cdn])
  end

  test "add package restriction with depending active errata" do
    @restriction.destroy
    # create 5 depending errata
    active_errata = []
    number = 5
    number.times { active_errata << create_errata(@package.brew_builds.first) }

    assert_no_difference('PackageRestriction.count') do
      visit "/variants/#{@variant.id}/package_restrictions/new"
      fill_in 'package_restriction_package', :with => @package.name
      select @cdn.name, :from => "package_restriction_push_targets"
      select @rhn_live.name, :from => "package_restriction_push_targets"
      click_on 'Save'
    end

    # Prefill
    assert_equal @package.name, find_field('package_restriction_package').value
    assert_array_equal(
      [@rhn_live, @cdn].map{|t| t.id.to_s},
      find_field('package_restriction_push_targets').value
    )
    assert_active_errata_error
    # should show the active errata table now.
    assert_active_errata_table(active_errata, @table_title, @table_note)
  end
end
