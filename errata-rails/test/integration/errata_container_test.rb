require 'test_helper'

class ErrataContainerTest < ActionDispatch::IntegrationTest

  setup do
    @docker_errata = Errata.find(24604)
    assert @docker_errata.has_docker?
  end

  test 'container tab is shown on tab bar' do
    auth_as devel_user
    visit "/advisory/#{@docker_errata.id}"
    within('.eso-tab-bar') do
      assert has_link? 'Container'
    end
  end

  test 'read-only user can view container actions' do
    auth_as read_only_user
    [:container, :container_content, :modal_container_text].each do |action|
      visit url_for :controller => :errata, :action => action, :id => @docker_errata.id
      assert_equal 200, page.status_code
    end
  end

  test 'container content for advisory' do
    auth_as devel_user
    visit "/errata/container_content/#{@docker_errata.id}"

    # The data is returned from cache, not lightblue
    assert_equal 'Unable to contact Lightblue, returning cached data', page.response_headers['X-ET-Alert']

    # All builds should be listed
    @docker_errata.brew_builds.each { |build| assert page.has_text? build.nvr }

    # Links to CVEs
    @docker_errata.container_cves.each { |cve| assert page.has_link? cve }

    # Image comparison
    comparison = @docker_errata.brew_builds.first.container_content.container_repos.first.comparison
    upgrade_rpms = comparison[:rpms][:upgrade]

    comparison_popover = page.find_link('', href: '#comparison')
    popover_content = comparison_popover['data-content']

    assert_match "Upgrade (#{upgrade_rpms.count})", popover_content
    upgrade_rpms.each do |rpm|
      assert_match rpm, popover_content
    end

    # Container content errata with bug ids and descriptions
    @docker_errata.container_errata.each do |ce|
      assert page.has_link? ce.advisory_name
      ce.bugs.each do |bug|
        assert page.has_link? bug.id
        assert page.has_text? bug.short_desc
      end
    end
  end

  test 'container content when build not in lightblue' do
    e = Errata.find(21101)

    # clear out cached container content
    e.brew_builds.each{ |build| build.container_content.destroy; build.reload }

    auth_as devel_user

    VCR.use_cassette 'lightblue_missing_build' do
      visit "/errata/container_content/#{e.id}"
    end

    e.brew_builds.each do |build|
      # Build NVR shown in alert flash message
      assert_match build.nvr, page.response_headers['X-ET-Alert']

      # Build link still shown on page
      assert page.has_css?('a', text: build.nvr)
    end
  end

  test 'consolidate repository errata' do
    cc = @docker_errata.brew_builds.first.container_content
    assert cc
    repo_name = 'test/repo_name'
    # Add a new repo with same errata, to check it's shown as consolidated
    cc.container_repos << ContainerRepo.new(:name => repo_name, :errata => cc.container_repos.first.errata)

    auth_as devel_user

    # Container tab
    visit "/errata/container_content/#{@docker_errata.id}"
    # The repo name should appear only once
    assert_equal 1, page.body.scan(repo_name).count

    # Container text
    visit "/errata/modal_container_text/#{@docker_errata.id}"
    # The repo name should appear only once
    assert_equal 1, page.body.scan(repo_name).count

    # Confirm that cached container_errata are still there
    assert @docker_errata.container_errata.any?
  end

end
