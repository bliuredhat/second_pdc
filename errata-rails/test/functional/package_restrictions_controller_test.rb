require 'test_helper'

class PackageRestrictionsControllerTest < ActionController::TestCase
  setup do
    auth_as admin_user

    @package = BrewBuild.first.package
    @variant_7Client = Variant.find_by_name("7Client")
    @variant_5Client = Variant.find_by_name("5Client")
    @variant_6Server = Variant.find_by_name("6Server")
    @cdn = PushTarget.find_by_name("cdn")
    @package_restriction = PackageRestriction.first
    @ftp = PushTarget.find_by_name("ftp")
    @altsrc = PushTarget.find_by_name("altsrc")
    @invalid_package = Package.new(:name => 'Invalid Pacakge')
    # set the http referer to prevent error from redirect_to :back
    @request.env['HTTP_REFERER'] = new_variant_package_restriction_path(@variant_7Client)
    @active_errata_error_message =
      'Validation failed: Add/Update/Delete restriction rule for package that has active'\
      ' advisories with locked filelist is not allowed. To amend the rule, please make sure'\
      " all depending active advisories are either inactive or in unlocked state."
  end

  def test_limit_package_to_push_targets(variant, package, push_targets, different)
    assert_difference("PackageRestriction.count", different) do
      post :create, {
        :variant_id => variant.id,
        :package_restriction => {
          :package => package.name,
          :push_targets => push_targets.map(&:id)
        },
      }
    end
  end

  def test_update_push_targets(package_restriction, push_targets, different)
    package = package_restriction.package
    variant = package_restriction.variant

    assert_difference("RestrictedPackageDist.count", different) do
      post :update, {
        :id => package_restriction.id,
        :package_restriction => {
          :package => package.name,
          :push_targets => push_targets.map(&:id)
        },
      }
    end
  end

  def prepare_errata_with_package_restriction
    build   = BrewBuild.find(201792)
    package = build.package

    # create a package restriction
    test_limit_package_to_push_targets(@variant_7Client, package, [@cdn],  1)
    package_restriction = PackageRestriction.last

    # create new errata and attach the brew of the restricted package
    errata = create_test_rhba('RHEL-7.0.0', build.nvr)
    pass_rpmdiff_runs(errata)
    errata.change_state!(State::QE, qa_user)

    return errata, package_restriction
  end

  def assert_html(expected_message, actual_message, response = :redirect)
    assert_response response
    assert_match(/#{Regexp.escape(expected_message)}/, actual_message)
  end

  test "new" do
    get :new, { :variant_id => @variant_7Client.id }
    assert_response :success
  end

  test "limit package to push to nowhere" do
    test_limit_package_to_push_targets(@variant_7Client, @package, [],  1)

    new_restriction = PackageRestriction.last
    assert_array_equal [], new_restriction.push_targets

    expected_message =
      "Package '#{@package.name}' for variant '#{@variant_7Client.name}'"\
      " is set to push to nowhere now"

    assert_html(expected_message, flash[:notice])
  end

  test "limit package to push to cdn only" do
    push_targets = [@cdn]
    test_limit_package_to_push_targets(@variant_7Client, @package, push_targets,  1)

    new_restriction = PackageRestriction.last
    assert_array_equal push_targets, new_restriction.push_targets

    expected_message =
      "Package '#{@package.name}' for variant '#{@variant_7Client.name}'"\
      " is set to push to cdn now"

    assert_html(expected_message, flash[:notice])
  end

  test "limit package to all push targets that are supported by the variant" do
    expected_push_targets = @variant_7Client.push_targets
    PackageRestriction.any_instance.expects(:active_errata).never
    test_limit_package_to_push_targets(@variant_7Client, @package,expected_push_targets, 1)

    new_restriction = PackageRestriction.last
    assert_array_equal expected_push_targets, new_restriction.push_targets

    expected_message =
      "Package '#{@package.name}' for variant '#{@variant_7Client.name}'"\
      " is set to push to #{expected_push_targets.map(&:name).join(', ')} now"
    assert_html(expected_message, flash[:notice])
  end

  test "limit package to nowhere should fail if it has active errata" do
    PackageRestriction.any_instance.expects(:active_errata).twice.returns(Errata.limit(1))
    test_limit_package_to_push_targets(@variant_7Client, @package, [], 0)

    assert_html(@active_errata_error_message, flash[:error], :success)
  end

  test "limit package to unsupported push target should fail" do
    # RHEL 5 does not support cdn
    test_limit_package_to_push_targets(@variant_5Client, @package, [@cdn],  0)

    expected_message =
      "Validation failed: Push target Variant '5Client' does not allow cdn."\
      " Only allows rhn_stage, rhn_live"
    assert_html(expected_message, flash[:error], :success)
  end

  test "create duplicate restriction for a package should fail" do
    package = @package_restriction.package
    variant = @package_restriction.variant
    test_limit_package_to_push_targets(variant, package, [], 0)

    expected_message = "Validation failed: Package Restriction already exists."
    assert_html(expected_message, flash[:error], :success)
  end

  test "update push targets for package" do
    package = @package_restriction.package
    variant = @package_restriction.variant
    expected_push_targets = @package_restriction.push_targets.to_a.concat([@cdn])
    expected_message =
      "Package '#{package.name}' for variant '#{variant.name}' is set"\
      " to push to #{expected_push_targets.map(&:name).join(', ')} now"

    assert_not_equal(
      @package_restriction.push_targets.to_a.sort,
      expected_push_targets.sort,
      "Fixture error: Old and new push target cannot be the same"
    )

    test_update_push_targets(@package_restriction, expected_push_targets, 1)

    @package_restriction.reload
    assert_array_equal expected_push_targets, @package_restriction.push_targets
    assert_html(expected_message, flash[:notice])
  end

  test "update invalid push target for package should fail" do
    variant = @package_restriction.variant

    [@ftp, @altsrc].each do |target|
      expected_message =
        "Validation failed: Push target Variant '#{variant.name}' does not"\
        " allow #{target.name}. Only allows #{variant.push_targets.map(&:name).join(', ')}"

      test_update_push_targets(@package_restriction, [target], 0)

      assert_html(expected_message, flash[:error])
    end
  end

  test "update package push target that has active advisories should fail" do
    errata, package_restriction = prepare_errata_with_package_restriction

    # Should get error when trying to update the rule because the advisory is locked
    test_update_push_targets(package_restriction, [], 0)
    assert_html(@active_errata_error_message, flash[:error])

    # Should be able to update the rule now, because the errata is in NEW_FILES stage
    errata.change_state!(State::NEW_FILES, qa_user)
    test_update_push_targets(package_restriction, [], -1)

    success_message =
      "Package '#{package_restriction.package.name}' for variant"\
      " '#{@variant_7Client.name}' is set to push to nowhere now"

    assert_html(success_message, flash[:notice])
  end

  test "should not raise error if no push targets has changed" do
    errata, package_restriction = prepare_errata_with_package_restriction
    package = package_restriction.package
    variant = package_restriction.variant
    push_targets = package_restriction.push_targets

    Variant.any_instance.expects(:has_no_active_errata).never
    test_update_push_targets(package_restriction, push_targets, 0)

    success_message =
      "Package '#{package.name}' for variant '#{variant.name}' is set"\
      " to push to #{push_targets.map(&:name).join(', ')} now"
    assert_html(success_message, flash[:notice])
  end

  test "destroy a package restriction" do
    assert_difference("PackageRestriction.count", -1) do
      post :destroy, :id => @package_restriction.id
    end

    assert_raises(ActiveRecord::RecordNotFound) do
       @package_restriction.reload
    end

    expected_message =
      "Restriction for package '#{@package_restriction.package.name}'"\
      " has been deleted successfully."
    assert_html(expected_message, flash[:notice])
  end

  test "destroy a package restriction that has active advisories should fail" do
    errata, package_restriction = prepare_errata_with_package_restriction

    assert_no_difference("PackageRestriction.count") do
      post :destroy, :id => package_restriction.id
    end
    assert_html(@active_errata_error_message, flash[:error])
  end

  test "limit package with invalid package name should fail" do
    test_limit_package_to_push_targets(@variant_7Client, @invalid_package, [],  0)

    expected_message = "Couldn't find Package with name '#{@invalid_package.name}'"
    assert_html(expected_message, flash[:error], :success)
  end

  test "limit package with empty parameter should fail" do
    post :create, { :variant_id => @variant_7Client.id }
    assert_html("Validation failed: Package can't be blank", flash[:error], :success)
  end
end
