require 'test_helper'

class ChannelsControllerTest < ActionController::TestCase

  setup do
    @channel = Channel.last
    auth_as admin_user
  end

  test "channel json response" do
    get :show, :id => @channel.id, :product_version_id => @channel.product_version.id, :format => :json
    assert_response :success
    data = JSON.load(response.body)

    # Sanity check
    assert_equal [@channel.id, @channel.name], [data['id'], data['name']]

    # Includes expected fields?
    expected_keys = %w[id type name has_stable_systems_subscribed variant arch].sort
    assert_array_equal expected_keys, data.keys.sort
  end

  test "channels json response" do
    get :index, :product_version_id => @channel.product_version.id, :format => :json
    assert_response :success
    data = JSON.load(response.body)

    # Sanity check
    assert_equal @channel.name, data.find{ |d| d['id'] == @channel.id }['name']

    # Includes expected fields?
    # (could also include a 'linked_from' key if channel was a linked channel)
    expected_keys = %w[id type name has_stable_systems_subscribed variant arch active].sort
    data.each{ |channel_data| assert_array_equal expected_keys, channel_data.keys.sort }
  end

  test 'cannot create channel with invalid type' do
    assert_no_difference('Channel.count') do
      post :create, :product_version_id => 201, :channel => {
        :name => 'my-hacked-channel',
        :arch_id => 4,
        :variant_id => 505,
        :type => 'bad-type',
      }
    end
    assert_response :success

    assert_match %r{\b1 error prohibited this channel from being saved\b}, response.body
    assert_match %r{\bType is not valid\b}, response.body
  end

  test 'can unlink a channel' do
    channel_id = 553
    pv_id = 153
    link = ChannelLink.joins(:variant).where(:channel_id => channel_id, :errata_versions => {:product_version_id => pv_id})
    assert link.any?
    assert_difference('ChannelLink.count', -1) do
      post :unlink, :product_version_id => pv_id, :id => channel_id
      assert_response :redirect, response.body
      channel = Channel.find(channel_id).name
      assert_equal "RHN channel '#{channel}' has been detached with product version 'RHEL-6-RHEV' successfully.", flash[:notice]
    end
    refute link.reload.any?
  end

  test "request js attach form" do
    v =  Variant.find_by_name!("6Server")
    pv = v.product_version
    get :attach_form, :format => :js, :variant_id => v.id

    assert_response :ok
    assert_match(/Attach RHN channel to 6Server/, response.body)
    assert_match(/Please enter RHN channel to be attached:/, response.body)
    # has save button
    assert_match(/Save/, response.body)
  end

  test "cannot delete channel with tps jobs" do
    channel = Channel.find_by_name("rhel-x86_64-client-6")
    assert channel.tps_jobs.count > 0, "Fixture error: Channel '#{channel.name}' no longer has tps jobs."

    assert_no_difference('Channel.count') do
      post :destroy, :id => channel.id, :product_version_id => channel.product_version.id, :format => :json
    end

    assert_testdata_equal "api/channels/delete_channel_with_links_and_tps.json", formatted_json_response
  end

  test 'disallow removing channel in use for multi product mappings' do
    pv = ProductVersion.find(252)
    variant = pv.variants.last
    # prepare new channels to make sure it doesn't have any other dependencies
    # or constraints
    ['test_channel_1', 'test_channel_2'].each do |name|
      PrimaryChannel.create(:name => name,
                            :type => 'PrimaryChannel',
                            :variant_id => variant.id,
                            :arch_id => 4,
                            :product_version => pv)
    end
    c1, c2 = PrimaryChannel.last(2)
    map = MultiProductChannelMap.create(:package => Package.find(14685),
                                        :origin_channel => c1,
                                        :origin_product_version => c1.product_version,
                                        :destination_channel => c2,
                                        :destination_product_version => c2.product_version,
                                        :user => admin_user)
    # multi product map uses the channels so can't delete the channels
    [ c1, c2 ].each do |channel|
      assert_no_difference('Channel.count') do
        assert_no_difference('MultiProductChannelMap.count') do
          delete :destroy,
                 :id => channel,
                 :product_version_id => channel.product_version
          assert_response :bad_request
          expected_message = "RHN channel &#x27;#{channel.name}&#x27; is depending by multi product mapped"
          assert_match(/#{Regexp.escape(expected_message)}/, response.body)
        end
      end
    end
    map.destroy
    # multi product mapping is removed so can delete the channels
    [ c1, c2 ].each do |channel|
      assert_difference('Channel.count', -1) do
        delete :destroy,
               :id => channel,
               :product_version_id => channel.product_version
        assert_response :redirect
        assert_equal "#{channel.class.display_name} '#{channel.name}' has been deleted successfully.", flash[:notice]
      end
    end
  end

  # Bug 1227156
  test "search by keyword results include RHEL-LE-7.1.Z and RHELSA-7.1.Z" do
    pv = ProductVersion.find_by_name!("RHEL-LE-7.1.Z")
    get :search_by_keyword, :name => 'rhel', :product_version_id => pv, :format => :json
    # Should return all RHEL-7 family, such as RHEL-7, RHEL-7.y.z, RHEL-LE-7.1.Z and RHELSA-7.1.Z etc
    assert_testdata_equal "api/channels/search_by_keyword_results_include_rhel_le_rhelsa.json", formatted_json_response
  end
end
