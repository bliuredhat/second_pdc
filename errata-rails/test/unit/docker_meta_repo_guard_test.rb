require 'test_helper'

class DockerMetaRepoGuardTest < ActiveSupport::TestCase

  def setup
    qr = StateTransition.find_by_from_and_to('NEW_FILES', 'QE')
    @guard = DockerMetaRepoGuard.new(
      :state_machine_rule_set => StateMachineRuleSet.last,
      :state_transition => qr
    )
  end

  test "returns default ok_message if errata is nil" do
    assert_equal 'Advisory metadata CDN repos not required', @guard.ok_message
  end

  test "docker advisory transition NEW_FILES to QE" do
    errata = Errata.find(21101)
    assert errata.has_docker?
    assert errata.docker_metadata_repos.empty?
    refute @guard.transition_ok?(errata)
    assert_equal 'Advisory metadata CDN repos not selected', @guard.failure_message(errata)

    DockerMetadataRepoList.create(:errata => errata)
    errata.reload.docker_metadata_repo_list.set_cdn_repos_by_id([21])
    errata.docker_metadata_repo_list.save!
    assert @guard.transition_ok?(errata)
    assert_equal 'Advisory metadata CDN repos selected', @guard.ok_message(errata)
  end

  test "non-docker advisory passes guard" do
    errata = Errata.find(20836)
    refute errata.has_docker?
    assert errata.docker_metadata_repos.empty?
    assert @guard.transition_ok?(errata)
    assert_equal 'Advisory metadata CDN repos not required', @guard.ok_message(errata)
  end

end
