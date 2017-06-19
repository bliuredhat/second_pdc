require 'test_helper'

class MetaxorTest < ActiveSupport::TestCase

  setup do
    @errata = Errata.find(24604)
    @builds = @errata.brew_builds
    @cassette_name = "metaxor_container_content_for_builds_#{@errata.id}"
  end

  test 'cache_only does not call lightblue' do
    Lightblue::Entity::ContainerImage.any_instance.expects(:repositories_for_brew_builds).never
    Metaxor.new.container_content_for_builds(@builds, :cache_only)
  end

  test 'lazy_fetch does not call lightblue for cached builds' do
    Lightblue::Entity::ContainerImage.any_instance.expects(:repositories_for_brew_builds).never
    Metaxor.new.container_content_for_builds(@builds, :lazy_fetch)
  end

  test 'lazy_fetch calls lightblue for non-cached builds' do
    ContainerContent.destroy_all
    Lightblue::Entity::ContainerImage.any_instance.expects(:repositories_for_brew_builds).once.returns([])
    Lightblue::ErrataClient.any_instance.expects(:validate).returns(nil)
    Metaxor.new.container_content_for_builds(@builds, :force_update)
  end

  test 'update_changed does not update cache if lastUpdateDate unchanged' do
    Lightblue::ErrataClient.any_instance.expects(:validate).returns(nil)
    cached_content = Metaxor.new.container_content_for_builds(@builds, :cache_only)

    content = VCR.use_cassette @cassette_name do
      Metaxor.new.container_content_for_builds(@builds, :update_changed)
    end

    assert_equal cached_content, content
  end

  test 'update_changed updates cache if lastUpdateDate changed' do
    Lightblue::ErrataClient.any_instance.expects(:validate).returns(nil)
    ContainerContent.update_all(:mxor_updated_at => '20161001T09:00:00.123-0400')
    cached_content = Metaxor.new.container_content_for_builds(@builds, :cache_only)

    content = VCR.use_cassette @cassette_name do
      Metaxor.new.container_content_for_builds(@builds, :update_changed)
    end

    assert_not_equal cached_content, content
  end

  test 'lightblue authentication error' do
    # Clear out cached container content for @builds
    @builds.each{ |build| build.container_content.destroy; build.reload }

    mxor = Metaxor.new(:warn_on_error => true)
    content = VCR.use_cassette 'lightblue_authentication_error' do
      mxor.container_content_for_builds(@builds, :force_update)
    end

    # expected warnings from mxor
    assert_match /Unable to contact Lightblue, returning cached data/, mxor.warnings.first
    @builds.each { |build| assert_match build.nvr, mxor.warnings.second }
  end

  test 'build does not exist in lightblue' do
    e = Errata.find(21101)

    # clear out cached container content
    e.brew_builds.each{ |build| build.container_content.destroy; build.reload }

    assert e.has_docker?

    mxor = Metaxor.new(:warn_on_error => true)
    content = VCR.use_cassette 'lightblue_missing_build' do
      mxor.container_content_for_builds(e.brew_builds, :force_update)
    end

    # expected warnings from mxor
    assert_match /Unable to contact Lightblue, returning cached data/, mxor.warnings.first
    e.brew_builds.each { |build| assert_match build.nvr, mxor.warnings.second }
  end

  test 'always use latest published build details returned from lightblue' do

    # Lightblue sometimes returns multiple sets of data for each build
    # We are only interested in the most recent published data (or the
    # latest if none are published).
    # The response from Lightblue appears to be sorted by lastUpdateDate,
    # but we can't rely on this, so the test response below is mixed up.

    lb_response = [
      {:lastUpdateDate=>"20170126T18:17:14.772-0500", :repositories=>[{:repository=>"openshift3/ose-egress-router", :published=>true, :tags=>[{:name=>"latest"}, {:name=>"v3.4"}, {:name=>"v3.4.0.40"}, {:name=>"v3.4.0.40-1"}]}], :brew=>{:build=>"openshift-enterprise-egress-router-docker-v3.4.0.40-1"}},
      {:lastUpdateDate=>"20170127T18:17:14.772-0500", :repositories=>[{:repository=>"openshift3/ose-egress-router", :tags=>[{:name=>"latest"}, {:name=>"v3.4"}, {:name=>"v3.4.0.40"}, {:name=>"v3.4.0.40-1"}]}], :brew=>{:build=>"openshift-enterprise-egress-router-docker-v3.4.0.40-1"}},
      {:lastUpdateDate=>"20170124T12:28:25.280-0500", :repositories=>[{:repository=>"openshift3/ose-egress-router", :tags=>[{:name=>"latest"}, {:name=>"v3.4"}, {:name=>"v3.4.0.40"}, {:name=>"v3.4.0.40-1"}]}], :brew=>{:build=>"openshift-enterprise-egress-router-docker-v3.4.0.40-1"}},
      {:lastUpdateDate=>"20170127T18:21:19.931-0500", :repositories=>[{:repository=>"openshift3/ose-keepalived-ipfailover", :tags=>[{:name=>"latest"}, {:name=>"v3.4"}, {:name=>"v3.4.0.40"}, {:name=>"v3.4.0.40-1"}]}], :brew=>{:build=>"openshift-enterprise-keepalived-ipfailover-docker-v3.4.0.40-1"}},
      {:lastUpdateDate=>"20170126T18:21:19.931-0500", :repositories=>[{:repository=>"openshift3/ose-keepalived-ipfailover", :published=>true, :tags=>[{:name=>"latest"}, {:name=>"v3.4"}, {:name=>"v3.4.0.40"}, {:name=>"v3.4.0.40-1"}]}], :brew=>{:build=>"openshift-enterprise-keepalived-ipfailover-docker-v3.4.0.40-1"}},
      {:lastUpdateDate=>"20170124T12:28:57.464-0500", :repositories=>[{:repository=>"openshift3/openvswitch", :tags=>[{:name=>"latest"}, {:name=>"v3.4"}, {:name=>"v3.4.0.40"}, {:name=>"v3.4.0.40-1"}]}], :brew=>{:build=>"openshift-enterprise-openvswitch-docker-v3.4.0.40-1"}},
      {:lastUpdateDate=>"20170124T12:30:12.637-0500", :repositories=>[{:repository=>"openshift3/ose-keepalived-ipfailover", :tags=>[{:name=>"latest"}, {:name=>"v3.4"}, {:name=>"v3.4.0.40"}, {:name=>"v3.4.0.40-1"}]}], :brew=>{:build=>"openshift-enterprise-keepalived-ipfailover-docker-v3.4.0.40-1"}},
      {:lastUpdateDate=>"20170126T18:17:29.560-0500", :repositories=>[{:repository=>"openshift3/openvswitch", :published=>true, :tags=>[{:name=>"latest"}, {:name=>"v3.4"}, {:name=>"v3.4.0.40"}, {:name=>"v3.4.0.40-1"}]}], :brew=>{:build=>"openshift-enterprise-openvswitch-docker-v3.4.0.40-1"}},
      {:lastUpdateDate=>"20170127T18:17:29.560-0500", :repositories=>[{:repository=>"openshift3/openvswitch", :tags=>[{:name=>"latest"}, {:name=>"v3.4"}, {:name=>"v3.4.0.40"}, {:name=>"v3.4.0.40-1"}]}], :brew=>{:build=>"openshift-enterprise-openvswitch-docker-v3.4.0.40-1"}}
    ]

    nvrs = [
      'openshift-enterprise-openvswitch-docker-v3.4.0.40-1',
      'openshift-enterprise-egress-router-docker-v3.4.0.40-1',
      'openshift-enterprise-keepalived-ipfailover-docker-v3.4.0.40-1'
    ]

    Lightblue::ErrataClient.any_instance.expects(:validate).returns(nil)
    Lightblue::Entity::ContainerImage.any_instance.expects(:repositories_for_brew_builds).once.returns(lb_response)

    mxor = Metaxor.new(:warn_on_error => true)
    latest = mxor.latest_repositories_for_nvrs(nvrs)

    assert_array_equal nvrs, latest.map{|r| r[:brew][:build]}
    latest.each do |r|
      assert_match /20170126/, r[:lastUpdateDate]
    end
  end
end
