require 'test_helper'

class DockerGuardTest < ActiveSupport::TestCase

  def setup
    qr = StateTransition.find_by_from_and_to('REL_PREP', 'PUSH_READY')
    @docker_guard = DockerGuard.new(
      :state_machine_rule_set => StateMachineRuleSet.last,
      :state_transition => qr
    )
  end

  test "returns default ok_message if errata is nil" do
    assert_equal 'All docker files are mapped to CDN repositories', @docker_guard.ok_message
  end

  test "normal REL_PREP to PUSH_READY transition" do
    errata = Errata.find(21100)
    errata.status = 'REL_PREP'
    assert @docker_guard.transition_ok?(errata)
  end

  test "image not mapped to a docker repository" do
    errata = Errata.find(21100)
    errata.status = 'REL_PREP'
    CdnRepoPackage.find(3).delete

    refute @docker_guard.transition_ok?(errata)
    assert_equal 'The following Docker builds are not mapped to any CDN repositories: rhel-server-docker-7.1-3', @docker_guard.failure_message(errata)
  end

end
