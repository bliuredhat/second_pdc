require 'test_helper'

# TODO: replace use of fakeweb with webmock and
# remove VCR.allow_http_connections_when_no_cassette hack
# See: Bug: 1434880
require 'fakeweb'

class TpsStreamsControllerTest < ActionController::TestCase
  include Tps
  setup do
    @variants = {
      :url => "http://#{Tps::TPS_SERVER}/variants.json",
      :body => [
        {"variant" => {"id" => 1, "name" => "Server"}},
        {"variant" => {"id" => 2, "name" => "Client"}},
        {"variant" => {"id" => 3, "name" => "ComputeNode"}},
      ],
      :content_type => "application/json",
    }

    @stream_types = {
      :url => "http://#{Tps::TPS_SERVER}/stream_types.json",
      :body => [
        {"stream_type" => {"id" => 1, "name" => "Main"}},
        {"stream_type" => {"id" => 2, "name" => "Z"}},
        {"stream_type" => {"id" => 3, "name" => "AUS"}},
      ],
      :content_type => "application/json",
    }

    @streams = {
      :url => "http://#{Tps::TPS_SERVER}/streams.json",
      :body => [
        {"stream" => { 'id' => 1, 'name' => 'RHEL-4', 'stream_type_id' => 1, 'variant_id' => 1, 'active' => false, 'parent_id' => nil}},
        {"stream" => { 'id' => 2, 'name' => 'RHEL-5', 'stream_type_id' => 1, 'variant_id' => 1, 'active' => false, 'parent_id' => nil}},
        {"stream" => { 'id' => 3, 'name' => 'RHEL-6', 'stream_type_id' => 1, 'variant_id' => 1, 'active' => true, 'parent_id' => nil}},
        {"stream" => { 'id' => 4, 'name' => 'RHEL-6.6', 'stream_type_id' => 2, 'variant_id' => 1, 'active' => true, 'parent_id' => 3}},
        {"stream" => { 'id' => 5, 'name' => 'RHEL-6.6', 'stream_type_id' => 3, 'variant_id' => 1, 'active' => true, 'parent_id' => 4}},
        {"stream" => { 'id' => 6, 'name' => 'RHEL-7', 'stream_type_id' => 1, 'variant_id' => 2, 'active' => true, 'parent_id' => nil}},
      ],
      :content_type => "application/json",
    }

    @not_found = {
      :url => "http://#{Tps::TPS_SERVER}/stream_types.json",
      :body => "Not Found",
      :status => ["404", "Not Found"]
    }

    VCR.configure do |c|
      c.allow_http_connections_when_no_cassette = true
    end
  end

  teardown do
    VCR.configure do |c|
      c.allow_http_connections_when_no_cassette = false
    end
  end

  def register_uri(data)
    # deep clone the data here, so that we don't break the original one
    clone_data = Marshal.load( Marshal.dump(data) )
    # convert the body data to json if require
    clone_data[:body] = clone_data[:body].to_json if clone_data[:content_type] == 'application/json'
    FakeWeb.register_uri(:get, clone_data.delete(:url), clone_data)
  end

  test "sync tps stream without admin" do
    auth_as devel_user
    post :sync
    assert_match /You do not have permission to access this resource/, response.body
  end

  test "sync with tps server error" do
    auth_as admin_user
    register_uri(@not_found)
    post :sync
    assert_response :redirect
    assert_match /Error response from TPS server: 404/, flash[:error]
  end

  test "sync with invalid url" do
    auth_as admin_user
    Net::HTTP.stubs("get_response").raises(SocketError)
    post :sync
    assert_response :redirect
    assert_match /is unreachable/, flash[:error]
  end

  test "sync with unknown error" do
    auth_as admin_user
    Net::HTTP.stubs("get_response").raises(StandardError, "Unknown error")
    post :sync
    assert_response :error
    assert_match /Failed to connect to TPS server: Unknown error/, response.body
  end

  test "sync tps streams" do
    auth_as admin_user
    register_uri(@variants)
    register_uri(@stream_types)
    register_uri(@streams)

    # Make sure both variants and stream types are empties
    # before testing
    TpsStream.delete_all
    TpsVariant.delete_all
    TpsStreamType.delete_all

    assert_difference [ 'TpsVariant.count', 'TpsStreamType.count' ], 3 do
      post :sync
      assert_match /#{@variants[:body].size} Tps variants are created/, flash[:notice]
      assert_match /#{@stream_types[:body].size} Tps stream types are created/, flash[:notice]
    end
    assert_redirected_to :action => :index

    # Test to remove a variant and a stream_types from the fake tps server
    # and sync again.
    re_variants = Marshal.load( Marshal.dump(@variants) )
    re_variants[:body].reject!{|v| v['variant']['id'] == 2}

    re_stream_types = Marshal.load( Marshal.dump(@stream_types) )
    re_stream_types[:body].reject!{|v| v['stream_type']['id'] == 3}

    re_streams = Marshal.load( Marshal.dump(@streams) )
    re_streams[:body].reject!{|v| ['RHEL-4', 'RHEL-5'].include?(v['stream']['name'])}

    FakeWeb.clean_registry
    register_uri(re_variants)
    register_uri(re_stream_types)
    register_uri(re_streams)

    tps_streams_count = TpsStream.count

    assert_difference [ 'TpsVariant.count', 'TpsStreamType.count' ], -1 do
      post :sync
      assert_match /1 Tps variant is deleted/, flash[:notice]
      assert_match /1 Tps stream type is deleted/, flash[:notice]
    end

    # 4 TPS streams are deleted in total.
    # - 2 are deleted because the related TPS variant and stream type are deleted (cascade delete)
    # - 2 are deleted by the TPS server. The message only count those deleted by the TPS server.
    assert_equal tps_streams_count - 4, TpsStream.count
    assert_match /2 Tps streams are deleted/, flash[:notice]

    assert_redirected_to :action => :index

    # Test to sync with duplicate tps variants
    FakeWeb.clean_registry
    new_variant = @variants[:body].select{|v| v['variant']['id'] == 2}.first
    re_variants[:body].push(new_variant)
    re_variants[:body].push(new_variant)
    register_uri(re_variants)
    register_uri(re_stream_types)
    register_uri(re_streams)

    # Should only added 1
    assert_difference [ 'TpsVariant.count'], 1 do
      post :sync
    end
    assert_redirected_to :action => :index
  end
end
