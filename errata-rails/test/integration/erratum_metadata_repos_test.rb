require 'test_helper'

class ErratumMetadataReposApiTest < ActionDispatch::IntegrationTest
  setup do
    auth_as devel_user
  end

  test 'repo index baseline test' do
    with_baselines('api/v1/erratum_metadata_repos/repos', %r{errata_(\d+).json$}) do |file,id|
      get "/api/v1/erratum/#{id}/metadata_cdn_repos"
      formatted_json_response
    end
  end

  test 'update unavailable repo' do
    put_json '/api/v1/erratum/21101/metadata_cdn_repos', {:enabled => true, :repo => CdnRepo.find_by_name!('cdntest-foo').name}
    assert_testdata_equal 'api/v1/erratum_metadata_repos/repos/put_unavailable.json', formatted_json_response
  end

  test 'update repo with bad enabled value' do
    put_json '/api/v1/erratum/21101/metadata_cdn_repos', {:enabled => "true", :repo => CdnRepo.find_by_name!('rhel-6-server-rpms__6Server__x86_64').name}
    assert_testdata_equal 'api/v1/erratum_metadata_repos/repos/put_bad_enabled.json', formatted_json_response
  end

  test 'update repo with wrong method' do
    assert_raises(AbstractController::ActionNotFound) do
      post_json '/api/v1/erratum/21101/metadata_cdn_repos', {:enabled => true, :repo => CdnRepo.find_by_name!('rhel-6-server-rpms__6Server__x86_64').name}
    end
  end

  test 'update repo with garbage' do
    put_json '/api/v1/erratum/21101/metadata_cdn_repos', {:foo => [:bar, :baz]}
    assert_testdata_equal 'api/v1/erratum_metadata_repos/repos/put_garbage.json', formatted_json_response
  end

  test 'update repos' do
    e = Errata.find(21101)
    repos = e.active_cdn_repos_for_available_product_versions.select(&:is_binary_repo?).sort_by(&:id)

    assert_equal 59, repos.length

    # initially empty
    assert_nil e.docker_metadata_repo_list

    # enable a couple
    put_json "/api/v1/erratum/#{e.id}/metadata_cdn_repos", repos[0..1].map{|r| {:enabled => true, :repo => r.name}}
    assert_testdata_equal 'api/v1/erratum_metadata_repos/repos/put_repo_1.json', formatted_json_response

    # the enabled repos were assigned
    assert_equal repos[0..1], e.reload.docker_metadata_repo_list.get_cdn_repos.sort_by(&:id)

    # enable one more while flipping another to false
    put_json "/api/v1/erratum/#{e.id}/metadata_cdn_repos", [
      {:enabled => false, :repo => repos[1].id},
      {:enabled => true,  :repo => repos[2].id}
    ]
    assert_testdata_equal 'api/v1/erratum_metadata_repos/repos/put_repo_2.json', formatted_json_response

    assert_equal [repos[0], repos[2]], e.reload.docker_metadata_repo_list.get_cdn_repos.sort_by(&:id)

    # disable all individually
    repos.each do |r|
      put_json "/api/v1/erratum/#{e.id}/metadata_cdn_repos", {:enabled => false, :repo => r.id}
    end
    assert_testdata_equal 'api/v1/erratum_metadata_repos/repos/put_disable_repos.json', formatted_json_response

    assert_equal [], e.reload.docker_metadata_repo_list.get_cdn_repos
  end
end
