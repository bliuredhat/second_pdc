require 'test_helper'

class ErrataTpsTest < ActionDispatch::IntegrationTest

  setup do
    rhn_stage = PushTarget.find_by_push_type(:rhn_stage)
    pv = ProductVersion.find_by_name 'RHEL-6'
    active_push_target = pv.active_push_targets.find_by_push_target_id(rhn_stage.id)

    # stubs the destroy validation for push targets and make sure the push
    # target can be remove
    VariantPushTarget.any_instance.stubs(:can_destroy?).returns(true)
    RestrictedPackageDist.any_instance.stubs(:can_destroy?).returns(true)
    # Remove Rhn Stage, so we only have to deal with one push job and
    # it's possible outcome.
    pv.active_push_targets.delete(active_push_target)

    pass_rpmdiff_runs rhba_async
    rhba_async.change_state!(State::QE, qa_user)
    pass_tps_runs rhba_async
    sign_builds rhba_async
    rhba_async.approve_docs!

    Settings.stubs(:enable_tps_cdn).returns(true)
  end

  #
  # For CDN enabled advisories, it is important that the advisory can
  # be pushed to CDN stage. The successful push job will schedule the
  # cdnqa_jobs (distqa). If rhn stage is disabled, this test is to
  # re-assure that running distqa is still possible.
  #
  # Bug: 1076325
  #
  test "can move to REL_PREP with DistQA instead of RHNQA" do
    auth_as qa_user

    summary_url = "/advisory/#{rhba_async.id}"
    visit summary_url
    click_on 'Push Now'
    click_on 'Push'

    assert has_text? 'Ok'

    #
    # Pass the push job as successful and finish the cdnqa jobs.
    #
    CdnStagePushJob.last.pub_success!
    assert rhba_async.tps_run.cdnqa_tps_jobs.any?, "Last CdnStagePushJob should have created cdnqa jobs"
    pass_tps_runs(rhba_async)

    # move to REL_PREP - SUCCESS!
    rhba_async.change_state!(State::REL_PREP, qa_user)
    assert rhba_async.state_in? :REL_PREP
  end

end
