require 'test_helper'

class MultiProductMappingsControllerTest < ActionController::TestCase
  setup do
    auth_as admin_user
  end

  def verify_mapping_display  
    get :index
    assert_response :success
    all_mappings = MultiProductChannelMap.all.to_a + MultiProductCdnRepoMap.all.to_a
    enabled_source_mappings = MultiProductChannelMap.with_enabled_product_version.to_a + MultiProductCdnRepoMap.with_enabled_product_version.to_a
    # just verify that only mappings with enabled sources are displayed somehow
    all_mappings.each do |m|
      if enabled_source_mappings.include? m
        assert response.body.include?(m.package.name), "missing package #{m.package.name}:\n#{response.body}"
        assert response.body.include?(m.origin.name), "missing origin #{m.origin.name}:\n#{response.body}"
        assert response.body.include?(m.destination.name), "missing destination #{m.destination.name}:\n#{response.body}"
        m.subscribers.each do |user|
          assert response.body.include?(user.login_name), "missing subscriber #{user.login_name}:\n#{response.body}"
        end
      else
        refute(response.body.include?(m.origin.name) && response.body.include?(m.destination.name))
      end
    end
  end

  def verify_mapping_json
    get :index, :format => 'json'
    assert_response :success

    arr = ActiveSupport::JSON.decode(response.body)
    id_and_type = arr.collect{|x| [x['id'], x['type']]}
    expected_rhn_id = MultiProductChannelMap.with_enabled_product_version.to_a.map(&:id).sort
    expected_cdn_id = MultiProductCdnRepoMap.with_enabled_product_version.to_a.map(&:id).sort

    assert_array_equal expected_rhn_id, id_and_type.collect{|x| x[0] if x[1] == 'rhn'}.compact.sort
    assert_array_equal expected_cdn_id, id_and_type.collect{|x| x[0] if x[1] == 'cdn'}.compact.sort
  end

  test 'html index only shows mappings for enabled sources' do
    auth_as devel_user
    # disable origin product version
    origin_product_version = ProductVersion.find(149)
    origin_product_version.update_attribute(:enabled, 0)
    verify_mapping_display

    # disable destination prodcut version
    origin_product_version.update_attribute(:enabled, 1)
    destination_product_version = ProductVersion.find(284)
    destination_product_version.update_attribute(:enabled, 0)
    verify_mapping_display
  end

  test 'json index only shows mappings for enabled sources' do
    auth_as devel_user
    # disable origin product version
    origin_product_version = ProductVersion.find_by_id(149)
    origin_product_version.update_attribute(:enabled, 0)
    verify_mapping_json

    # disable destination prodcut version
    origin_product_version.update_attribute(:enabled, 1)
    destination_product_version = ProductVersion.find_by_id(284)
    destination_product_version.update_attribute(:enabled, 0)
    verify_mapping_json
  end

  test 'html index shows all mappings' do
    auth_as devel_user
    # disable origin or destination product version
    origin_product_version = ProductVersion.find_by_id(149)
    origin_product_version.update_attribute(:enabled, 0)

    destination_product_version = ProductVersion.find_by_id(284)
    destination_product_version.update_attribute(:enabled, 0)

    get :index, :scope => 'all'
    assert_response :success
    # just verify that every mapping including product versions disabled is displayed somehow
    (MultiProductChannelMap.all.to_a + MultiProductCdnRepoMap.all.to_a).each do |m|
      assert response.body.include?(m.package.name), "missing package #{m.package.name}:\n#{response.body}"
      assert response.body.include?(m.origin.name), "missing origin #{m.origin.name}:\n#{response.body}"
      assert response.body.include?(m.destination.name), "missing destination #{m.destination.name}:\n#{response.body}"
      m.subscribers.each do |user|
        assert response.body.include?(user.login_name), "missing subscriber #{user.login_name}:\n#{response.body}"
      end
    end
  end

  test 'json index shows all mappings' do
    auth_as devel_user
    # disable origin or destination product version
    origin_product_version = ProductVersion.find_by_id(149)
    origin_product_version.update_attribute(:enabled, 0)

    destination_product_version = ProductVersion.find_by_id(284)
    destination_product_version.update_attribute(:enabled, 0)

    get :index, :scope => 'all', :format => 'json'
    assert_response :success

    arr = ActiveSupport::JSON.decode(response.body)
    id_and_type = arr.collect{|x| [x['id'], x['type']]}
    expected_rhn_id = MultiProductChannelMap.all.to_a.map(&:id).sort
    expected_cdn_id = MultiProductCdnRepoMap.all.to_a.map(&:id).sort

    assert_array_equal expected_rhn_id, id_and_type.collect{|x| x[0] if x[1] == 'rhn'}.compact.sort
    assert_array_equal expected_cdn_id, id_and_type.collect{|x| x[0] if x[1] == 'cdn'}.compact.sort
  end

  test 'disallows creating duplicate mapping' do
    mapping = MultiProductCdnRepoMap.last
    params = {
      'package' => mapping.package.name,
      'mapping_type' => mapping.mapping_type,
      'origin' => mapping.origin.name,
      'destination' => mapping.destination.name
    }
    assert_no_difference 'MultiProductChannelMap.count' do
      post :create, :multi_product_channel_map => params
    end
    assert_response :success, @response.body
    assert_select 'div#errorExplanation h2', '1 error prohibited this multi product cdn repo map from being saved'
    assert_select 'div#errorExplanation ul li', 'Origin cdn repo A mapping already exists for rhel-6-server-rpms__6Server__x86_64 =&gt; rhel-6-rhev-s-rpms__6Server-RHEV-S__x86_64 for package sblim-cim-client2'
  end

  test 'disallows updating to existing mapping' do
    first, second = MultiProductCdnRepoMap.last(2)
    second_params = {
      'package' => second.package.name,
      'mapping_type' => second.mapping_type,
      'origin' => second.origin.name,
      'destination' => second.destination.name
    }
    put :update, :id => first.id, :multi_product_channel_map => second_params
    assert_response :success, @response.body
    assert_select 'div#errorExplanation h2', '1 error prohibited this multi product cdn repo map from being saved'
    assert_select 'div#errorExplanation ul li', 'Origin cdn repo A mapping already exists for rhel-6-server-rpms__6Server__x86_64 =&gt; rhel-6-rhev-s-rpms__6Server-RHEV-S__x86_64 for package sblim-cim-client2'
  end

  test 'disallows channel of RHEL as a destination' do
    rhel_channel = Product.find_by_name('Red Hat Enterprise Linux').
                   product_versions.first.channels.first
    params = {
      'package' => 'augeas',
      'mapping_type' => 'channel',
      'origin' => 'rhel-ppc-server-hts-5',
      'destination' => rhel_channel.name
    }
    assert_no_difference 'MultiProductChannelMap.count' do
      post :create, :multi_product_channel_map => params
    end
    assert_select 'div#errorExplanation h2', '1 error prohibited this multi product channel map from being saved'
    assert_select 'div#errorExplanation ul li', 'Destination product version RHEL or RHEL Optional is _not_ allowed as a destination'
  end
end
