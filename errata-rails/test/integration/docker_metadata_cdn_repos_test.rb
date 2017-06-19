require 'test_helper'

class DockerMetadataCdnReposTest < ActionDispatch::IntegrationTest

  test "can set docker metadata repos successfully" do
    errata = Errata.find(21101)

    # No docker metadata repos set yet
    assert_nil errata.docker_metadata_repo_list

    repos = %w{rhel-7-desktop-rpms__7Client__x86_64 rhel-7-desktop-fastrack-rpms__x86_64}
    auth_as devel_user
    visit "/errata/docker_cdn_repos/#{errata.id}"

    # No Docker, Source or DebugInfo repos should be listed
    refute has_text? '(Docker)'
    refute has_text? '(Source)'
    refute has_text? '(DebugInfo)'

    repos.each { |name| check name }

    assert_difference('errata.comments.count', 1) do
      click_on 'Update'
    end
    assert_not_nil errata.reload.docker_metadata_repo_list
    assert has_text?('Advisory metadata CDN repositories updated')
    assert_match /Advisory metadata CDN repositories set to/, errata.comments.last.text

    # Open the docker_cdn_repos page again
    first(:css, '.workflow-step-name-set_metadata_cdn_repos').click_on 'Set'

    repos.each { |name| assert has_checked_field? name }

    # The repo selection has not been changed
    assert_no_difference('errata.comments.count') do
      click_on 'Update'
    end
    assert has_text?('Advisory metadata CDN repositories have not been changed')

    # Open the docker_cdn_repos page again
    first(:css, '.workflow-step-name-set_metadata_cdn_repos').click_on 'Set'

    repos.each { |name| uncheck name }

    # Now there are no repos selected
    assert_difference('errata.comments.count', 1) do
      click_on 'Update'
    end
    assert has_text?('Advisory metadata CDN repositories have been cleared')
    assert_match /Advisory metadata CDN repositories have been cleared/, errata.comments.last.text

  end

end
