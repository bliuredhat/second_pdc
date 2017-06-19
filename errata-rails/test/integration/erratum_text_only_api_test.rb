require 'test_helper'

class ErratumTextOnlyApiTest < ActionDispatch::IntegrationTest
  setup do
    auth_as devel_user
  end

  test 'channel index baseline test' do
    with_baselines('api/v1/erratum_text_only/channels', %r{errata_(\d+).json$}) do |file,id|
      get "/api/v1/erratum/#{id}/text_only_channels"
      formatted_json_response
    end
  end

  test 'repo index baseline test' do
    with_baselines('api/v1/erratum_text_only/repos', %r{errata_(\d+).json$}) do |file,id|
      get "/api/v1/erratum/#{id}/text_only_repos"
      formatted_json_response
    end
  end

  test 'update unavailable channel' do
    put_json '/api/v1/erratum/16654/text_only_channels', {:enabled => true, :channel => Channel.find_by_name!('rhel-i386-server-optional-6').name}
    assert_testdata_equal 'api/v1/erratum_text_only/channels/put_unavailable.json', formatted_json_response
  end

  test 'update channel with bad enabled value' do
    put_json '/api/v1/erratum/16654/text_only_channels', {:enabled => "true", :channel => Channel.find_by_name!('rhel-x86_64-server-6-rhevm-3.4').name}
    assert_testdata_equal 'api/v1/erratum_text_only/channels/put_bad_enabled.json', formatted_json_response
  end

  test 'update channel with wrong method' do
    # TODO: make it return 405 Method Not Allowed?
    assert_raises(AbstractController::ActionNotFound) do
      post_json '/api/v1/erratum/16654/text_only_channels', {:enabled => true, :channel => Channel.find_by_name!('rhel-x86_64-server-6-rhevm-3.4').name}
    end
  end

  test 'update channel with garbage' do
    put_json '/api/v1/erratum/16654/text_only_channels', {:foo => [:bar, :baz]}
    assert_testdata_equal 'api/v1/erratum_text_only/channels/put_garbage.json', formatted_json_response
  end

  test 'update unavailable repo' do
    put_json '/api/v1/erratum/16654/text_only_repos', {:enabled => true, :repo => CdnRepo.find_by_name!('cdntest-foo').name}
    assert_testdata_equal 'api/v1/erratum_text_only/repos/put_unavailable.json', formatted_json_response
  end

  test 'update repo with bad enabled value' do
    put_json '/api/v1/erratum/16654/text_only_repos', {:enabled => "true", :repo => CdnRepo.find_by_name!('rhel-6-server-rhev-agent-rpms__6Server__i386').name}
    assert_testdata_equal 'api/v1/erratum_text_only/repos/put_bad_enabled.json', formatted_json_response
  end

  test 'update repo with wrong method' do
    assert_raises(AbstractController::ActionNotFound) do
      post_json '/api/v1/erratum/16654/text_only_repos', {:enabled => true, :repo => CdnRepo.find_by_name!('rhel-6-server-rhev-agent-rpms__6Server__i386').name}
    end
  end

  test 'update repo with garbage' do
    put_json '/api/v1/erratum/16654/text_only_repos', {:foo => [:bar, :baz]}
    assert_testdata_equal 'api/v1/erratum_text_only/repos/put_garbage.json', formatted_json_response
  end

  test 'update channels' do
    e = Errata.find(16654)
    channels = Channel.where(:name => %w[rhel-x86_64-server-6-rhevh rhel-x86_64-server-6-rhevm-3.4 rhel-x86_64-rhev-mgmt-agent-6]).to_a.sort_by(&:id)
    assert_equal 3, channels.length

    # initially empty
    assert_equal [], e.text_only_channel_list.get_channels

    put_json "/api/v1/erratum/#{e.id}/text_only_channels", {:enabled => true, :channel => channels.first.name}
    assert_testdata_equal 'api/v1/erratum_text_only/channels/put_channel_1.json', formatted_json_response

    # the enabled channel was assigned
    assert_equal [channels.first], e.reload.text_only_channel_list.get_channels

    # enable another single channel (this time using array form, and ID).
    # do it twice to demonstrate idempotence
    2.times do
      put_json "/api/v1/erratum/#{e.id}/text_only_channels", [{:enabled => true, :channel => channels.second.id}]
      assert_testdata_equal 'api/v1/erratum_text_only/channels/put_channel_2.json', formatted_json_response

      # the enabled channels were assigned, and the other was not modified
      assert_equal channels.take(2).sort_by(&:name), e.reload.text_only_channel_list.get_channels.sort_by(&:name)
    end

    # the channels can be disabled
    put_json "/api/v1/erratum/#{e.id}/text_only_channels", channels.map{|c| {:enabled => false, :channel => c.id}}
    assert_testdata_equal 'api/v1/erratum_text_only/channels/put_disable_channels.json', formatted_json_response

    assert_equal [], e.reload.text_only_channel_list.get_channels
  end

  test 'update repos' do
    e = Errata.find(16654)
    repos = e.available_product_versions.map(&:active_cdn_repos).flatten.uniq.sort_by(&:id)
    assert_equal 4, repos.length

    # initially empty
    assert_equal [], e.text_only_channel_list.get_cdn_repos

    # enable a couple
    put_json "/api/v1/erratum/#{e.id}/text_only_repos", repos[0..1].map{|r| {:enabled => true, :repo => r.name}}
    assert_testdata_equal 'api/v1/erratum_text_only/repos/put_repo_1.json', formatted_json_response

    # the enabled repos were assigned
    assert_equal repos[0..1], e.reload.text_only_channel_list.get_cdn_repos.sort_by(&:id)

    # enable one more while flipping another to false
    put_json "/api/v1/erratum/#{e.id}/text_only_repos", [
      {:enabled => false, :repo => repos[1].id},
      {:enabled => true,  :repo => repos[2].id}
    ]
    assert_testdata_equal 'api/v1/erratum_text_only/repos/put_repo_2.json', formatted_json_response

    assert_equal [repos[0], repos[2]], e.reload.text_only_channel_list.get_cdn_repos.sort_by(&:id)

    # disable all individually
    repos.each do |r|
      put_json "/api/v1/erratum/#{e.id}/text_only_repos", {:enabled => false, :repo => r.id}
    end
    assert_testdata_equal 'api/v1/erratum_text_only/repos/put_disable_repos.json', formatted_json_response

    assert_equal [], e.reload.text_only_channel_list.get_cdn_repos
  end
end
