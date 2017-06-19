require 'test_helper'

class CdnStagePushJobTest < ActiveSupport::TestCase

  setup do
    ProductVersion.find_by_name('RHEL-6').push_targets << PushTarget.find_by_push_type(:cdn_stage)
    # QE status advisory
    @cdn_advisory = Errata.find(11112)
    sign_builds(@cdn_advisory)

    @job = CdnStagePushJob.create(:errata => @cdn_advisory, :pushed_by => qa_user)

    Settings.stubs(:enable_tps_cdn).returns(true)
  end

  test "test fixture advisory supports cdn_stage" do
    assert @cdn_advisory.supports_cdn_stage?
    refute @cdn_advisory.rhnqa?
  end

  test "job provides schedule cdnqa jobs post push task" do
    task_name = 'reschedule_cdnqa_jobs'
    assert @job.post_push_tasks.include? 'reschedule_cdnqa_jobs'
    assert @job.respond_to?("task_#{task_name}", true)
  end

  test "job does not reschedule cdnqa jobs if text only errata" do
    text_only = mock('text only errata')
    text_only.stubs(:text_only? => true, :requires_tps? => false)
    @job.stubs(:errata).returns(text_only)

    assert @job.send(:task_reschedule_cdnqa_jobs).nil?
  end

  test "schedules cdnqa jobs after stage push" do
    assert @cdn_advisory.tps_run.cdnqa_tps_jobs.empty?

    force_sync_delayed_jobs do
      @job.pub_success!
    end

    @cdn_advisory.tps_run.reload
    assert @cdn_advisory.tps_run.cdnqa_tps_jobs.any?
  end

  test "sets rhnqa attribute successfully" do
    force_sync_delayed_jobs do
      @job.pub_success!
    end

    @cdn_advisory.reload
    assert @cdn_advisory.rhnqa?
    assert_equal 1, @cdn_advisory.rhnqa
  end

  test "provides mark rnqa successful task" do
    assert @job.valid_post_push_tasks.has_key? 'mark_rhnqa_done'
  end

  test "successfully returns push details" do
    details = @job.push_details
    assert_equal details['target'], @job.target
    assert_equal details['blockers'], @cdn_advisory.push_cdn_stage_blockers
    assert_equal details['can'], @job.can_push?
    assert       details['should']
  end

  test 'valid pub options' do
    assert_equal(%w(push_files push_metadata).sort,
                 @job.valid_pub_options.keys.sort)
  end

  test 'pub options defaults' do
    assert_equal false, @job.pub_options["push_metadata"]
    assert_equal false, @job.pub_options["push_files"]
  end

  test 'default push_files for CDN stage push job' do
    # Advisory containing docker image
    with_docker = Errata.find(21100)
    assert with_docker.has_docker?

    # Non-docker advisory
    without_docker = Errata.find(21009)
    refute without_docker.has_docker?

    assert CdnStagePushJob.new(:errata => without_docker).valid_pub_options['push_files'][:default],
      'Default push_files for non-docker advisory should be true'

    refute CdnStagePushJob.new(:errata => with_docker).valid_pub_options['push_files'][:default],
      'Default push_files for docker advisory should be false'

    # Should not be overwritten by default for docker
    assert CdnStagePushJob.new(:errata => without_docker).valid_pub_options['push_files'][:default],
      'Default push_files for non-docker advisory should be true'
  end
end
