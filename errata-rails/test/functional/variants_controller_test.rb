require 'test_helper'

class VariantsControllerTest < ActionController::TestCase
  setup do
    auth_as admin_user
    @variant_6Server = Variant.find_by_name("6Server")
    @ftp = PushTarget.find_by_name("ftp")
    @altsrc = PushTarget.find_by_name("altsrc")
  end

  test "index" do
    # Fixture data contains a product_version record with id=3
    get :index, { :product_version_id => 3 }
    assert_response :success
  end

  test 'requested variants should contain expected tps_stream with json' do
    get :index, :product_version_id => 3, :format => 'json'
    assert_response :success

    variants = JSON.parse(response.body)
    variants.each do |variant|
      object = Variant.find_by_id(variant['id'])
      result = variant['tps_stream']
      assert_nil object.tps_stream, "Expecting variant with unset tps_stream"
      assert_equal object.get_tps_stream, result, "Didn't respond the expected tps_stream"
    end
  end

  test "disabling a variant with json using update action" do
    variant = Variant.where(:enabled => true).first
    get :update, :id => variant.id, :variant => { :enabled => false }, :format => 'json'
    assert_response :success
    refute variant.reload.enabled?, "variant was not disabled!"
  end

  test 'requested tps_stream should be the value of get_tps_stream with json' do
    get :show, :id => 699, :format => 'json'
    assert_response :success

    variant = Variant.find_by_id(699)
    got = JSON.parse(response.body)

    assert_nil variant.tps_stream, "Expecting variant with unset tps_stream"
    assert_equal variant.get_tps_stream, got['tps_stream'], "Didn't respond the expected tps_stream"
  end

  test 'variants json contains expected fields' do
    get :show, :id => 699, :format => 'json'
    assert_response :success

    got = JSON.parse(response.body)

    %w[id name description cpe tps_stream enabled product product_version rhel_variant rhel_release].each do |field|
      assert got.has_key?(field), "Expected '#{field}' to be present in JSON response"
    end
  end

  # bug 1097727
  [
    [Channel, ChannelLink, 'rhel-i386-workstation-6', %r{\brhel-[a-zA-Z0-9\-_]+-6\b} ],
    [CdnRepo, CdnRepoLink, 'rhel-6-client-rpms__6Client__i586', %r{\brhel-6[a-zA-Z0-9\-_]+} ],
  ].each do |target_class, target_link_class, rhel6_target_name, rhel6_target_pattern|

    target_type = target_class.name.underscore

    test "variants show only displays related #{target_type}s" do
      rhel6_target = target_class.find_by_name!(rhel6_target_name)
      rhel7_variant = Variant.find_by_name!('7Client')

      assert rhel6_target.variant.send("#{target_type}s").length > 1,
        "test data problem: RHEL6 variant must have multiple #{target_type}s"

      target_link_class.create!(
        target_type => rhel6_target,
        :variant => rhel7_variant,
        :product_version => rhel7_variant.product_version)

      get :show, :id => rhel7_variant
      assert_response :success

      # with the fix, only displays the linked channel/repo.
      # without, displays all other channels/repos in the variant as well.
      displayed_rhel6_targets = response.body.scan( rhel6_target_pattern )
      assert_equal [rhel6_target.name], displayed_rhel6_targets, response.body
    end
  end

  def mock_errata_status
    # Fake errata to NEW_FILES or inactive state to prevent the validation
    # from raising error
    [ [RHEA, State::NEW_FILES],
      [RHSA, State::NEW_FILES],
      [RHBA, State::SHIPPED_LIVE],
    ].each do |klass, status|
      klass.any_instance.stubs(:status).returns(status)
    end
  end

  test 'preconditions' do
    errata = @variant_6Server.active_errata
    assert errata.count > 0, "Fixture error: The active errata count cannot be 0."
  end

  test 'unset push targets in variant level should also unset the package push targets' do
    mock_errata_status

    package_restriction = PackageRestriction.first
    variant_push_targets = package_restriction.variant.push_targets
    package_push_targets = package_restriction.package.push_targets
    different = package_push_targets - variant_push_targets
    variant = package_restriction.variant

    assert different.empty?, "Fixture error: package contains push targets that are not supported by the variant."

    expected_push_targets = variant_push_targets.reject{ |pt| package_push_targets.include?(pt) }

    assert_difference("VariantPushTarget.count", package_push_targets.count* -1) do
      post :update, :id => variant.id, :variant => { :push_targets => expected_push_targets}
    end

    assert_array_equal expected_push_targets, variant_push_targets.reload
    assert package_push_targets.reload.empty?
    assert_response :redirect
    assert_match(/Variant '#{variant.name}' was successfully updated/, flash[:notice])
  end

  test 'update variant push targets with active errata should fail' do
    assert_difference("VariantPushTarget.count", 0) do
      post :update, :id => @variant_6Server.id,
        :variant => { :push_targets => []},
        :product_version_id => @variant_6Server.product_version_id
    end

    expected_message =
      "Update push targets for variant that has active advisories with locked filelist"\
      " is not allowed. To amend the push targets, please make sure all depending active advisories"\
      " are either inactive or in unlocked state."

    assert_response :ok
    assert_match(/#{Regexp.escape(expected_message)}/, response.body)
  end

  test 'set unsupported variant push targets should fail with html' do
    mock_errata_status

    assert_no_difference("VariantPushTarget.count") do
      post :update, :id => @variant_6Server.id, :variant => { :push_targets => [@ftp.id]}, :format => :html
    end

    expected_message =
      "Push target Variant 6Server does not allow ftp."\
      " Only allows rhn_stage, rhn_live, cdn_stage, cdn"

    assert_response :bad_request
    assert_match(/#{Regexp.escape(expected_message)}/, response.body)
  end

  test 'set unsupported variant push targets should fail with json' do
    mock_errata_status

    [@altsrc, @ftp].each do |target|
      assert_no_difference("VariantPushTarget.count") do
        post :update, :id => @variant_6Server.id, :variant => { :push_targets => [target.id]}, :format => :json
      end

      expected_message =
        "Variant 6Server does not allow #{target.name}."\
        " Only allows rhn_stage, rhn_live, cdn_stage, cdn_docker_stage, cdn_docker, cdn"

      output = { :errors => { :push_target => [expected_message] } }
      assert_response :bad_request
      assert_equal(output.to_json, response.body)
    end
  end

  test "should not raise error when update fields other than push targets" do
    update_fields = {
      :name => "6Server-test",
      :description => 'test variant',
      :tps_stream => 'RHEL-6-Main-Server',
      :cpe => "cpe:/test" }
    Variant.any_instance.expects(:has_no_active_errata).never
    post :update, :id => @variant_6Server.id, :variant => update_fields

    assert_response :redirect
    assert_match(/Variant '6Server-test' was successfully updated/, flash[:notice])

    @variant_6Server.reload
    update_fields.each_pair do |field, value|
      assert_equal value, @variant_6Server.send(field)
    end
  end

  test "variant cpe can only be updated by certain users" do
    update_fields = { :cpe => "cpe:/test" }
    Variant.any_instance.expects(:has_no_active_errata).never

    auth_as releng_user
    post :update, :id => @variant_6Server.id, :variant => update_fields
    assert_response :forbidden

    auth_as admin_user
    post :update, :id => @variant_6Server.id, :variant => update_fields
    assert_response :redirect
    assert_match(/Variant '6Server' was successfully updated/, flash[:notice])
  end

  test 'create new variant' do
    rhel_v = Variant.find_by_name("6Server")
    pv = ProductVersion.find_by_name("RHEL-6")
    targets = PushTarget.where(:name => %w[rhn_live rhn_stage])
    params = {
      :rhel_variant_id => rhel_v.id,
      :name => "6Server-test",
      :push_targets => targets.map(&:id),
      :description => "This is a test",
    }

    assert_difference("Variant.count", 1) do
      post :create, :product_version_id => pv.id, :variant => params
    end

    new_v = Variant.last
    assert_equal "6Server-test", new_v.name
    assert_equal rhel_v, new_v.rhel_variant

    expected_message = "Variant '6Server-test' was successfully created"
    assert_response :redirect
    assert_match(/#{Regexp.escape(expected_message)}/, flash[:notice])
  end
end
