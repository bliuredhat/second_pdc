require 'test_helper'

#
# This is not very detailed or thorough, but should catch any obvious push job snafus.
#
class PushErrataFormTest < ActionDispatch::IntegrationTest
  def setup
    # I found this 'PUSH_READY' advisory in the fixture data.
    # Let's use it for testing pushes...
    @test_errata = Errata.find(10836)
    @push_live_url = "/rhn/push_errata/#{@test_errata.id}"
    @push_stage_url = "/rhn/push_errata/#{@test_errata.id}?stage=1"

    # Ensure we start with no active push jobs for this advisory
    assert_equal 0, PushJob.for_errata(@test_errata).active_jobs.count

    auth_as releng_user

    # summary page
    visit url_for(:controller => :errata, :action => :view, :id => @test_errata)
  end

  test "user can push to RHN Stage successfully" do
    rhn_only = Errata.find(11110)
    visit url_for(:controller => :push, :action => :push_errata, :id => rhn_only, :stage => 1)

    check 'Do Rhn Stage push'
    check 'Immediately push to Stage'

    assert_difference('RhnStagePushJob.count') do
      click_on 'Push'
    end
    assert page.has_content?('push job submitted to pub')
  end

  test "user can push pdc advisory to RHN Stage successfully" do
    VCR.use_cassette('push_pdc_advisory_to_rhn_stage') do
      e = Errata.find(10000)

      # The VCR file doesn't include the ftp.redhat.com repo requests.
      # I don't want to add them to the cassette, so do this instead.
      Push::Ftp.stubs(:pdc_get_ftp_dir).returns("/some/ftp/path/")

      visit url_for(:controller => :push, :action => :push_errata, :id => e, :stage => 1)

      check 'Do Rhn Stage push'
      check 'Immediately push to Stage'

      assert_difference('RhnStagePushJob.count') do
        click_on 'Push'
      end
      assert page.has_content?('push job submitted to pub')
    end
  end

  test "allows user to push to RHN and CDN together" do
    find(:css, '.workflow-step-name-live_push').first(:link, "Push Now").click

    check 'Do Rhn Live push'
    check 'Do Cdn Live push'
    check 'Do Ftp push'
    check 'Do Altsrc push'


    assert_difference("PushJob.count", 4) do
      click_on 'Push'
    end
  end

  test 'can trigger real push while nochannel push is running' do
    nochannel_job = RhnLivePushJob.new(:errata => @test_errata, :pushed_by => releng_user)
    nochannel_job.set_defaults
    nochannel_job.pre_push_tasks = []
    nochannel_job.post_push_tasks = []
    nochannel_job.pub_options['nochannel'] = true
    nochannel_job.save!

    find(:css, '.workflow-step-name-live_push').first(:link, 'Push Now').click

    check 'Do Rhn Live push'

    assert_difference('RhnLivePushJob.count') do
      click_on 'Push'
    end
  end

  test "can not push CDN Live before having pushed to RHN Live" do
    visit @push_live_url

    uncheck 'Do Rhn Live push'
    assert_no_difference('CdnPushJob.count') do
      click_on 'Push'
    end

    assert page.has_content? 'Advisory has not been shipped to rhn live channels yet.'
    assert page.has_content? 'Ftp push job submitted to pub'
  end

  test "successfully pushes rhn and cdn stage" do
    visit @push_stage_url

    assert page.has_content?('Do Cdn Stage push')

    check 'Do Rhn Stage push'
    check 'Immediately push to Stage' # otherwise it will enqueue a push

    assert_difference("PushJob.count", 2) do
      click_on 'Push'
    end

    assert page.has_content? 'Rhn stage push job submitted to pub'
    assert page.has_content? 'Cdn stage push job submitted to pub'

    # Should be a new push job there now
    assert_equal 1, RhnStagePushJob.for_errata(@test_errata).active_jobs.count, "New RHN Stage push job not found"
    assert_equal 1, CdnStagePushJob.for_errata(@test_errata).active_jobs.count

    # Go back to push form
    visit @push_stage_url


    # Should have messages about existing job
    # (and you can't push again)
    assert page.has_content?('existing Rhn Stage Push Job')
    assert page.has_content?('existing Cdn Stage Push Job')
    assert page.has_no_checked_field? 'Do Rhn Stage push'
    assert page.has_no_checked_field? 'Do Cdn Stage push'
  end

  test "rhn live and ftp push form" do
    visit @push_live_url

    # Let's do both an rhn and an ftp push
    check 'Do Rhn Live push'
    check 'Do Ftp push'
    uncheck 'Do Cdn Live push'
    uncheck 'Do Altsrc push'
    click_on 'Push'

    assert page.has_content?('Rhn live push job submitted to pub'), "Can't see LIVE push confirmation: #{page.html}"
    assert page.has_content?('Ftp push job submitted to pub'),  "Can't see FTP push confirmation: #{page.html}"

    # Should be two push jobs now
    assert_equal 2, PushJob.for_errata(@test_errata).active_jobs.count, "New push jobs not found"
    # One each of each type, RHNLive and Ftp
    assert_equal 1, RhnLivePushJob.for_errata(@test_errata).active_jobs.count, "New RHN Live push job not found"
    assert_equal 1, FtpPushJob.for_errata(@test_errata).active_jobs.count, "New FTP push job not found"

    # Tiny bit of sanity checking on the options and pre/post tasks...
    # We didn't check or uncheck any of the options so the defaults should be set.
    # Actually it's pretty confusing since there are mandatory tasks that get force-added,
    # (see RhnLivePushJob). This is very rough and really doesn't test much, but better
    # than nothing at all I guess...
    rhn_live_push_job = RhnLivePushJob.for_errata(@test_errata).active_jobs.last
    assert rhn_live_push_job.pub_options["push_metadata"]
    assert rhn_live_push_job.pre_push_tasks.include?("set_update_date")
    assert rhn_live_push_job.post_push_tasks.include?("update_bugzilla")

    # Go back to push form
    visit @push_live_url

    # Should have messages about existing jobs
    # (and you can't push again)
    assert page.has_content?('existing Rhn Live Push Job'), "Can't see existing job message"
    assert page.has_content?('existing Ftp Push Job'), "Can't see existing job message"
    assert page.has_checked_field?('Do Cdn Live push')
  end

  #
  # Bug: 1069980
  #
  # Checkboxes are de-selected if the push was successful for the pushed
  # type.
  #
  # Note: An additional unit test exists in
  # test/unit/helpers/push_helper_test.rb which tests this more
  # thoroughly. I kept this integration test, since methods may change
  # in the way we detect a successful push, which should fail this test,
  # but could possibly leave the push_helper_test running without a
  # shout.
  #
  test "successful push will provide unchecked options" do
    visit @push_live_url

    click_on 'Push'
    # One is successful, one is failed
    RhnLivePushJob.for_errata(@test_errata).active_jobs.last.mark_as_failed!('Server down')
    CdnPushJob.for_errata(@test_errata).active_jobs.last.pub_success!
    FtpPushJob.for_errata(@test_errata).active_jobs.last.pub_success!

    @test_errata.reload

    visit @push_live_url

    assert has_unchecked_field?('Do Cdn Live push')
    assert has_unchecked_field?('Do Ftp push')
    assert has_link?('Last job (COMPLETE)')
  end

  test "push from rel_prep if ship_date is empty" do
    rel_prep = Errata.valid_only.rel_prep.first
    assert rel_prep.publish_date < Time.current

    assert_can_change_state(State::PUSH_READY, :allow, rel_prep)
  end

  test "can not push from rel_prep if ship_date is set" do
    rel_prep = Errata.valid_only.rel_prep.first
    rel_prep.update_attribute('publish_date_override', 1.day.from_now)

    assert_can_change_state(State::REL_PREP, :disallow, rel_prep)
  end

  test "push form displays appropriately if CDN is supported but not applicable" do
    visit "/rhn/push_errata/19028"

    # RHN and FTP pushes should be offered as usual (and checked by default)
    ['Rhn Live', 'Ftp'].each do |type|
      within(:xpath, push_fieldset(type)) do
        assert has_checked_field?("Do #{type} push"), "Missing ticked checkbox for #{type}\n#{page.html}"
        refute has_text?('Not available'), "wrong text displayed for #{type}"
        refute has_text?("Can't push advisory"), "wrong text displayed for #{type}"
      end
    end

    within(:xpath, push_fieldset('Cdn Live')) do
      # CDN live push should not be offered, with an explanation
      refute has_field?('Do Cdn Live push')
      assert has_text?('Not available'), page.html
      assert has_text?("Can't push advisory to Cdn Live now due to: There are no CDN Repos"), page.html
    end
  end

  def restricted_live_push_test(errata, expected_text)
    visit "/rhn/push_errata/#{errata.id}"

    assert has_text?(expected_text), page.html

    assert_difference('PushJob.count', 3) do
      click_on 'Push'
    end

    # It still creates the other push jobs OK, and executing them
    # moves advisory to SHIPPED_LIVE as usual
    errata.reload.push_jobs.order('id desc').limit(3).each(&:pub_success!)
    assert_equal 'SHIPPED_LIVE', errata.reload.status
  end

  test 'push works OK when rhn live is restricted' do
    restricted_live_push_test(Errata.find(19030), "Can't push advisory to Rhn Live now due to: Rhn Live is not supported")
  end

  test 'push works OK when cdn is restricted' do
    # fixtures have a push job failed in post-push tasks for this advisory.
    # clean it for this test.
    e = Errata.find(19032)
    RhnLivePushJob.for_errata(e).delete_all
    restricted_live_push_test(e, "Can't push advisory to Cdn Live now due to: Cdn is not supported")
  end

  # Bug 1188563
  # The "push summary" part of the view was crashing for a
  # text-only advisory.
  test 'push triggered OK for text-only advisory' do
    e = Errata.find(16616)
    visit "/rhn/push_errata/#{e.id}"

    assert has_checked_field?('Do Rhn Live push'), page.html
    assert has_checked_field?('Do Cdn Live push'), page.html

    assert_difference('PushJob.count', 2) do
      click_on 'Push'
    end

    assert has_text?('Rhn live push job submitted to pub'), page.html
    assert has_text?('Cdn push job submitted to pub'), page.html
  end

  test "cannot push from REL_PREP if batch release date in future" do
    advisory = erratum_with_batch(:release_date => 1.week.from_now)
    visit "/errata/modal_change_state/#{advisory.id}"
    assert page.has_no_field?('state_push_ready', :type => 'radio')
    assert page.has_css?('.state_indicator_push_ready')
  end

  test "can push from REL_PREP if batch release date in past" do
    advisory = erratum_with_batch(:release_date => 1.day.ago)
    visit "/errata/modal_change_state/#{advisory.id}"
    assert page.has_field?('state_push_ready', :type => 'radio')
    assert page.has_css?('.state_indicator_push_ready')
  end

  test 'nochannel option is offered for live push' do
    visit '/push/push_errata/19028'
    assert has_text?('Do Rhn Live push'), page.html
    assert has_text?('Skip subscribing packages (nochannel)'), page.html
  end

  test 'nochannel option is not offered for stage push' do
    visit '/push/push_errata/19028?stage=1'
    assert has_text?('Do Rhn Stage push'), page.html
    refute has_text?('nochannel'), page.html
  end

  test 'docker push' do
    errata = Errata.find(21100)
    assert errata.has_docker?

    visit "/push/push_errata/#{errata.id}"
    assert has_text?('Do Cdn Docker push'), page.html
    assert has_text?('CDN docker metadata'), page.html

    # The "Upload errata files" option is hidden (bug 1359546)
    refute has_text?('Upload errata files'), page.html

    assert_difference('CdnPushJob.count', 1) do
      assert_difference('CdnDockerPushJob.count', 1) do
        click_on 'Push'
      end
    end

    cdn_push_job = CdnPushJob.last
    cdn_docker_push_job = CdnDockerPushJob.last

    assert_equal errata, cdn_push_job.errata
    assert_equal errata, cdn_docker_push_job.errata
    assert_equal false, cdn_push_job.pub_options['push_files']
  end

  def erratum_with_batch(batch_attributes)
    batch = Batch.find(4)
    batch.update_attributes(batch_attributes)
    advisory = Errata.find(11118)
    advisory.update_attribute('batch_id', 4)
    advisory
  end

  def push_fieldset(type)
    "//fieldset[.//*[contains(text(), '#{type} Push')]]"
  end

  def assert_can_change_state(expected_state, expect, advisory)
    visit "/errata/modal_change_state/#{advisory.id}"
    if expect == :allow
      assert advisory.push_ready_blockers.empty?

      assert page.has_field?('state_push_ready', :type => 'radio')
      choose 'PUSH READY'
      click_button 'Change'
    else # expect == :disallow
      refute advisory.push_ready_blockers.empty?

      assert page.has_no_field?('state_push_ready', :type => 'radio')
      assert page.has_css?('.state_indicator_push_ready')
    end

    advisory.reload
    assert_equal expected_state, advisory.current_state_index.current
  end

  test "warn if pushing docker advisory with unpushed content advisories" do
    docker_advisory = Errata.find(21100)
    assert docker_advisory.has_docker?
    assert_equal State::PUSH_READY, docker_advisory.status

    # No warning shown if there are no unpushed container errata
    refute docker_advisory.has_active_container_errata?
    visit url_for(:controller => :push, :action => :push_errata, :id => docker_advisory)
    refute has_text? 'A docker image included in this advisory contains RPM-based advisories that have not yet been shipped.'

    # Warning shown if there are unpushed container errata
    Errata.any_instance.expects(:has_active_container_errata?).at_least_once.returns(true)
    visit url_for(:controller => :push, :action => :push_errata, :id => docker_advisory)
    assert has_text? 'A docker image included in this advisory contains RPM-based advisories that have not yet been shipped.'
  end

end
