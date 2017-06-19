require 'test_helper'

class StagePushGuardTest < ActiveSupport::TestCase

  setup do
    @guard = StagePushGuard.new(
      :state_machine_rule_set => StateMachineRuleSet.last,
      :state_transition => StateTransition.find_by_from_and_to('QE', 'REL_PREP')
    )
  end

  test "stage push blocks standard advisory" do
    ProductVersion.find_by_name('RHEL-6').push_targets << PushTarget.find_by_push_type(:cdn_stage)

    # QE status advisory
    cdn_advisory = Errata.find(11112)
    sign_builds(cdn_advisory)

    # Start stage push
    job = CdnStagePushJob.create(:errata => cdn_advisory, :pushed_by => qa_user)

    # Blocked from REL_PREP as stage push incomplete
    refute @guard.transition_ok?(cdn_advisory)
    assert_equal 'Staging push jobs not complete', @guard.failure_message(cdn_advisory)

    # Complete CDN stage push
    complete_job(job)
    cdn_advisory.reload

    # No longer blocked
    assert @guard.transition_ok?(cdn_advisory)
    assert_equal 'Staging push complete',  @guard.ok_message(cdn_advisory)
  end

  test "stage push blocks docker advisory" do
    # Advisory containing docker image
    advisory = Errata.find(21101)
    assert advisory.has_docker?

    # Move to QE state after pre-requisites
    DockerMetadataRepoList.create(:errata => advisory)
    advisory.docker_metadata_repo_list.set_cdn_repos_by_id([21])
    advisory.docker_metadata_repo_list.save!
    advisory.change_state!(State::QE, qa_user)

    # Blocked from REL_PREP as stage push incomplete
    refute @guard.transition_ok?(advisory)
    assert_equal 'Staging push jobs not complete', @guard.failure_message(advisory)

    # Start stage push
    cdn_job = CdnStagePushJob.create(:errata => advisory, :pushed_by => qa_user)
    docker_job = CdnDockerStagePushJob.create(:errata => advisory, :pushed_by => qa_user)

    # Still blocked
    refute @guard.transition_ok?(advisory)

    # Complete CDN stage push
    complete_job(cdn_job)

    # Still blocked
    refute @guard.transition_ok?(advisory)
    assert_equal 'Staging push jobs not complete', @guard.failure_message(advisory)

    # Complete CDN Docker stage push
    complete_job(docker_job)

    # No longer blocked
    assert @guard.transition_ok?(advisory)
    assert_equal 'Staging push complete',  @guard.ok_message(advisory)
  end

  def complete_job(job)
    force_sync_delayed_jobs do
      job.pub_task_id = 1
      job.pub_success!
    end
  end

end
