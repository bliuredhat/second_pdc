require 'test_helper'

class RhnLivePushJobTest  < ActiveSupport::TestCase
  setup do
    # Bug 1053533: An advisory will be blocked in NEW_FILES state if a build
    # that contains rpms has missing product listing. I will simply mock
    # this check here to make the test easy.
    BuildGuard.any_instance.stubs(:transition_ok? => true)
  end

  test "rhn live push job" do
    e = make_advisory
    job = RhnLivePushJob.new(:errata => e, :pushed_by => qa_user)

    assert !job.valid?
    job.pushed_by = releng_user
    
    assert !job.valid?
    assert !job.can_push?

    e.stubs(:can_push_rhn_live?).returns(true)
    assert job.can_push?
    
    job.post_push_tasks << 'update_bugzilla'
    assert job.valid?, errors_to_string(job)

    job.post_push_tasks << 'push_oval_to_secalert'
    assert !job.valid?
    
    e.stubs(:is_security?).returns(true)
    assert job.valid?, errors_to_string(job)

    job.save!
    assert job.pub_options.has_key?('push_files')
    assert job.pub_options.has_key?('push_metadata')

    assert_equal false, job.pub_options['push_files']
    assert_equal false, job.pub_options['push_metadata']

    assert job.pre_push_tasks.include?('set_update_date'), "Update date not set"
    assert job.pre_push_tasks.include?('set_issue_date'), "Issue date not set"

  end

  test "pdc rhn live push job" do
    nvr = 'ceph-10.2.3-17.el7cp'
    release_name = 'ReleaseForPDC'
    VCR.use_cassette 'pdc_rhn_live_push_job' do
     VCR.use_cassettes_for :pdc_ceph21 do
      e = create_test_rhba(release_name, nvr)

      job = RhnLivePushJob.new(:errata => e, :pushed_by => qa_user)

      # Nothing met the requirement, Job is invalid
      assert !job.valid?
      job.pushed_by = releng_user

      assert !job.valid?
      assert !job.can_push?

      e.stubs(:can_push_rhn_live?).returns(true)
      # Job can push now
      assert job.can_push?

      job.post_push_tasks << 'update_bugzilla'
      assert job.valid?, errors_to_string(job)

      job.post_push_tasks << 'push_oval_to_secalert'
      refute job.valid?

      e.stubs(:is_security?).returns(true)
      assert job.valid?, errors_to_string(job)

      # Every requirement is met, can save now
      job.save!
      assert job.pub_options.has_key?('push_files')
      assert job.pub_options.has_key?('push_metadata')

      assert_equal false, job.pub_options['push_files']
      assert_equal false, job.pub_options['push_metadata']

      assert job.pre_push_tasks.include?('set_update_date'), "Update date not set"
      assert job.pre_push_tasks.include?('set_issue_date'), "Issue date not set"
     end
    end
  end

  test 'post tasks only' do
    e = Errata.find(13147)
    assert e.shipped_live?
    job = RhnLivePushJob.create!(:errata => e, :pushed_by => releng_user)
    job.save!
    assert job.skip_pub_task_and_post_process_only?, "Metadata and/or files somehow set? #{job.pub_options.inspect}"
    pc = Push::PubClient.get_connection
    ex = assert_raise(RuntimeError) { job.create_pub_task(pc) }
    assert_equal "Advisory is flagged to skip pub and only run post push tasks", ex.message
    job.start_post_push_processing!(true)
    assert_equal 'POST_PUSH_PROCESSING', job.status
    dj = Delayed::Job.last
    payload = dj.payload_object
    assert_equal "AR:RhnLivePushJob:#{job.id}", payload.object
    assert_equal :run_post_push_tasks, payload.method
  end

  test 'to completion' do
    e = make_advisory
    get_push_ready e
    job = RhnLivePushJob.create!(:errata => e, :pushed_by => releng_user)
    job.set_defaults
    pc = Push::PubClient.get_connection
    pc.stubs(:submit_push_job).returns(90210)
    job.create_pub_task(pc)
    assert_equal 'WAITING_ON_PUB', job.status, job.log
    job.pub_success!
    assert_equal 'COMPLETE', job.status, job.log
  end

  test 'post push failure' do
    e = make_advisory
    get_push_ready e
    job = RhnLivePushJob.create!(:errata => e, :pushed_by => releng_user)
    job.set_defaults
    pc = Push::PubClient.get_connection
    pc.stubs(:submit_push_job).returns(90210)
    job.create_pub_task(pc)
    assert_equal 'WAITING_ON_PUB', job.status, job.log
    job.stubs(:task_mark_errata_shipped).raises(RuntimeError, 'Failed to make SHIPPED_LIVE')
    job.pub_success!
    assert_equal 'POST_PUSH_PROCESSING', job.status, job.log
    assert_match 'Error running task mark_errata_shipped', job.log, job.log
  end

  test 'shadow push sets appropriate defaults' do
    e = make_advisory
    get_push_ready e
    e.release.stubs(:allow_shadow? => true)
    job = RhnLivePushJob.create!(:errata => e, :pushed_by => releng_user, :pub_options => {'shadow' => true})

    job.pre_push_tasks.each do |key|
      # special cases
      next if %w[set_issue_date set_update_date].include?(key)
      LivePushTasks::PRE_PUSH_TASKS[key].tap{|task|
        assert task[:shadow], "job incorrectly included non-shadow pre-push task #{key}"
        assert task[:default] || task[:mandatory], "job incorrectly included non-default/mandatory pre-push task #{key}"
      }
    end
    # these are always included when pushcount is 0, even though not marked :default or :shadow
    assert job.pre_push_tasks.include?('set_issue_date')
    assert job.pre_push_tasks.include?('set_update_date')

    job.post_push_tasks.each do |key|
      LivePushTasks::POST_PUSH_TASKS[key].tap{|task|
        assert task[:shadow], "job incorrectly included non-shadow pre-push task #{key}"
        assert task[:default] || task[:mandatory], "job incorrectly included non-default/mandatory pre-push task #{key}"
      }
    end

    job.pub_options.each do |key,val|
      next if key == 'shadow'
      RhnLivePushJob::PUB_OPTIONS[key].tap{|opt| assert_equal opt[:default], val, "job incorrectly set pub option #{key} = #{val}"}
    end
    assert job.pub_options['shadow'], job.pub_options.inspect
  end

  protected
  def get_push_ready(errata)
    errata.stubs(:rpmdiff_finished?).returns(true)
    errata.change_state!('QE', admin_user)
    errata.update_attribute(:rhnqa, true)
    errata.stubs(:tps_finished?).returns(true)
    errata.stubs(:tpsrhnqa_finished?).returns(true)
    errata.stubs(:docs_approved?).returns(true)
    errata.stubs(:is_signed?).returns(true)
    errata.change_state!('REL_PREP', @radmin)
    errata.change_state!('PUSH_READY', admin_user)
  end

  def make_advisory
    e = RHBA.create!(:reporter => qa_user,
                    :synopsis => 'test advisory',
                    :product => Product.find_by_short_name('RHEL'),
                    :release => async_release,
                    :assigned_to => qa_user,
                    :content =>
                    Content.new(:topic => 'test',
                                :description => 'test',
                                :solution => 'fix it')
                    )
    build = BrewBuild.find_by_nvr! 'libdfp-1.0.4-1.el6'
    # RHEL 5 is RHN-only, to exclude CDN from this test
    map = ErrataBrewMapping.create!(:product_version => ProductVersion.find_by_name('RHEL-5'),
                                    :errata => e,
                                    :brew_build => build,
                                    :package => build.package)

    TestData.add_test_bug(e)

    # see test_helper.rb to know why
    mock_errata_product_listing(e)

    # file listing is normally created after commit, we need it now
    map.make_new_file_listing

    return e
  end
end
