require 'test_helper'

class Api::V1::PackageRestrictionsControllerTest < ActionController::TestCase
  setup do
    auth_as admin_user

    @package = BrewBuild.first.package
    @variant_7Client = Variant.find_by_name("7Client")
    @variant_5Client = Variant.find_by_name("5Client")
    @variant_6Server = Variant.find_by_name("6Server")
    @cdn = PushTarget.find_by_name("cdn")
    @altsrc = PushTarget.find_by_name("altsrc")
    @package_restriction = PackageRestriction.first
    @pr_variant = @package_restriction.variant
    @pr_package = @package_restriction.package
    @pr_push_targets = @package_restriction.push_targets
    @ftp = PushTarget.find_by_name("ftp")
    @invalid_package = Package.new(:name => 'Invalid Package')
    @active_errata_error_message =
      'Validation failed: Add/Update/Delete restriction rule for package that has active'\
      ' advisories with locked filelist is not allowed. To amend the rule, please make sure'\
      " all depending active advisories are either inactive or in unlocked state."
  end

  def prepare_errata_with_package_restriction
    build   = BrewBuild.find(201792)
    package = build.package

    # create a package restriction
    test_set_restriction(@variant_7Client, package, [@cdn],  1)
    package_restriction = PackageRestriction.last

    # create new errata and attach the brew of the restricted package
    errata = create_test_rhba('RHEL-7.0.0', build.nvr)
    pass_rpmdiff_runs(errata)
    errata.change_state!(State::QE, qa_user)

    return errata, package_restriction
  end

  def test_set_restriction(variant, package, push_targets, different)
    assert_difference("PackageRestriction.count", different) do
      post :set, {
        :variant => variant.name,
        :package => package.name,
        :push_targets => push_targets.map(&:name),
        :format => :json,}
    end
  end

  def test_delete_restriction(variant, package, different)
    assert_difference("PackageRestriction.count", different) do
      post :delete, {
        :variant => variant.name,
        :package => package.name,
        :format  => :json,}
    end
  end

  def assert_json(expected_result, status)
    assert_response status
    assert_equal expected_result.to_json, response.body
  end

  test "limit package to push to nowhere" do
    expected_message =
      "Package '#{@package.name}' for variant '#{@variant_7Client.name}'"\
      " is set to push to nowhere now."
    test_set_restriction(@variant_7Client, @package, [], 1)

    new_restriction = PackageRestriction.last
    assert_array_equal [], new_restriction.push_targets
    assert_json({:notice => expected_message}, :ok)
  end

  test "limit package to push to cdn only" do
    push_targets = [@cdn]
    test_set_restriction(@variant_7Client, @package, push_targets, 1)

    new_restriction = PackageRestriction.last
    assert_array_equal push_targets, new_restriction.push_targets

    expected_message =
      "Package '#{@package.name}' for variant '#{@variant_7Client.name}'"\
      " is set to push to cdn now."

    assert_json({:notice => expected_message}, :ok)
  end

  test "limit package to all push targets that are supported by the variant" do
    expected_push_targets = @variant_7Client.push_targets
    expected_message =
      "Package '#{@package.name}' for variant '#{@variant_7Client.name}'"\
      " is set to push to #{expected_push_targets.map(&:name).join(', ')} now."
    PackageRestriction.any_instance.expects(:active_errata).never
    test_set_restriction(@variant_7Client, @package, expected_push_targets, 1)

    new_restriction = PackageRestriction.last
    assert_array_equal expected_push_targets, new_restriction.push_targets
    assert_json({:notice => expected_message}, :ok)
  end

  test "limit package to nowhere should fail if it has active errata" do
    PackageRestriction.any_instance.expects(:active_errata).once.returns(Errata.limit(1))
    test_set_restriction(@variant_7Client, @package, [], 0)

    assert_json({:error => @active_errata_error_message}, :unprocessable_entity)
  end

  test "limit package to unsupported push target should fail" do
    # RHEL 5 does not support cdn
    test_set_restriction(@variant_5Client, @package, [@cdn], 0)

    expected_message =
      "Validation failed: Push target Variant '5Client' does not allow cdn."\
      " Only allows rhn_stage, rhn_live."
    assert_json({:error => expected_message}, :unprocessable_entity)
  end

  test "update push targets for package" do
    expected_push_targets = @pr_push_targets.to_a.concat([@cdn])
    expected_message =
      "Package '#{@pr_package.name}' for variant '#{@pr_variant.name}' is set"\
      " to push to #{expected_push_targets.map(&:name).join(', ')} now."
    # Should simply update the existing package restriction
    test_set_restriction(@pr_variant, @pr_package, expected_push_targets, 0)

    @package_restriction.reload
    assert_array_equal expected_push_targets, @package_restriction.push_targets
    assert_json({:notice => expected_message}, :ok)
  end

  test "update invalid push target for package should fail" do
    [@ftp, @altsrc].each do |target|
      expected_message =
        "Validation failed: Push target Variant '#{@pr_variant.name}' does not"\
        " allow #{target.name}. Only allows #{@pr_variant.push_targets.map(&:name).join(', ')}."
      test_set_restriction(@pr_variant, @pr_package, [target], 0)

      assert_json({:error => expected_message}, :unprocessable_entity)
    end
  end

  test "update package push target that has active advisories should fail" do
    errata, package_restriction = prepare_errata_with_package_restriction

    package = package_restriction.package
    variant = package_restriction.variant
    # Should get error when trying to update the rule because the advisory is locked
    test_set_restriction(variant, package, [], 0)
    assert_json({:error => @active_errata_error_message}, :unprocessable_entity)

    # Should be able to update the rule now, because the errata is in NEW_FILES stage
    errata.change_state!(State::NEW_FILES, qa_user)
    test_set_restriction(variant, package, [], 0)

    success_message =
      "Package '#{package_restriction.package.name}' for variant"\
      " '#{@variant_7Client.name}' is set to push to nowhere now."

    assert_json({:notice => success_message}, :ok)
  end

  test "should not raise error if no push targets has changed" do
    errata, package_restriction = prepare_errata_with_package_restriction
    package = package_restriction.package
    variant = package_restriction.variant
    push_targets = package_restriction.push_targets

    Variant.any_instance.expects(:has_no_active_errata).never
    test_set_restriction(variant, package, push_targets, 0)

    expected_message =
      "Package '#{package.name}' for variant '#{variant.name}' is set"\
      " to push to #{push_targets.map(&:name).join(', ')} now."
    assert_json({:notice => expected_message}, :ok)
  end

  test "destroy a package restriction with json" do
    test_delete_restriction(@pr_variant, @pr_package, -1)

    expected_message =
      "Restriction for package '#{@package_restriction.package.name}'"\
      " has been deleted successfully."
    assert_json({:notice => expected_message}, :ok)
  end

  test "destroy a package restriction that has active advisories should fail" do
    errata, package_restriction = prepare_errata_with_package_restriction
    package = package_restriction.package
    variant = package_restriction.variant
    test_delete_restriction(variant, package, 0)

    assert_json({:error => @active_errata_error_message}, :unprocessable_entity)
  end

  test "destroy an invalid package restriction should fail" do
    expected_message = "Couldn't find package restriction with variant"\
        " #{@variant_7Client.name} and #{@package.name}."
    test_delete_restriction(@variant_7Client, @package, 0)

    assert_json({:error => expected_message}, :unprocessable_entity)
  end

  test "limit package with invalid package name should fail" do
    expected_message = "Couldn't find Package with name '#{@invalid_package.name}'"
    test_set_restriction(@variant_7Client, @invalid_package, [],  0)

    assert_json({:error => expected_message}, :unprocessable_entity)
  end

  test "limit package with empty parameter should fail" do
    post :set, :format => :json

    assert_json({:error => "Couldn't find Variant with name ''"}, :unprocessable_entity)
  end
end