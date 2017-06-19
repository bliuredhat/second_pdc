require 'test_helper'

class CdnPushJobTest  < ActiveSupport::TestCase
  test "cdn push job" do
    
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
    map = ErrataBrewMapping.create!(:product_version => ProductVersion.find_by_name('RHEL-6'),
                                    :errata => e,
                                    :brew_build => build,
                                    :package => build.package)
    job = CdnPushJob.new(:errata => e, :pushed_by => qa_user)

    assert !job.valid?
    job.pushed_by = releng_user
    
    assert !job.valid?
    assert !job.can_push?

    e.stubs(:can_push_cdn?).returns(true)
    assert job.can_push?
    
    job.pre_push_tasks = CdnPushJob::PRE_PUSH_TASKS.keys
    job.post_push_tasks << 'some_fake_task'

    assert !job.valid?

    job.post_push_tasks -= ['some_fake_task']

    e.stubs(:supports_cdn?).returns(true)
    e.stubs(:supports_rhn_live?).returns(false)
    assert job.valid?, "Job invalid despite being cdn only: #{job.errors.full_messages.join(',')}"
    job.post_push_tasks << 'push_oval_to_secalert'
    assert !job.valid?
    
    e.stubs(:is_security?).returns(true)
    assert job.valid?
    
    job.save!
    assert job.pre_push_tasks.include?('set_update_date'), "Update date not set"
    assert job.pre_push_tasks.include?('set_issue_date'), "Issue date not set"
  end

  test "pdc cdn push job" do
    nvr = 'ceph-10.2.3-17.el7cp'
    release_name = 'ReleaseForPDC'
    VCR.use_cassette 'pdc_cdn_push_job' do
     VCR.use_cassettes_for(:pdc_ceph21) do
      e = create_test_rhba(release_name, nvr)

      job = CdnPushJob.new(:errata => e, :pushed_by => qa_user)

      # Nothing met the requirement, Job is invalid
      assert !job.valid?
      job.pushed_by = releng_user

      assert !job.valid?
      assert !job.can_push?

      e.stubs(:can_push_cdn?).returns(true)
      # Job can push now
      assert job.can_push?

      job.pre_push_tasks = CdnPushJob::PRE_PUSH_TASKS.keys
      job.post_push_tasks << 'some_fake_task'

      assert !job.valid?

      job.post_push_tasks -= ['some_fake_task']

      e.stubs(:supports_cdn?).returns(true)
      e.stubs(:supports_rhn_live?).returns(false)
      assert job.valid?, "Job invalid despite being cdn only: #{job.errors.full_messages.join(',')}"
      job.post_push_tasks << 'push_oval_to_secalert'
      # Job is still invalid although support cdn is set to true
      assert !job.valid?

      e.stubs(:is_security?).returns(true)
      # Every requirement is met
      assert job.valid?

      job.save!
      assert job.pre_push_tasks.include?('set_update_date'), "Update date not set"
      assert job.pre_push_tasks.include?('set_issue_date'), "Issue date not set"
     end
    end
  end

  test 'shadow push sets appropriate defaults' do
    e = Errata.find(16374)

    e.release.stubs(:allow_shadow? => true)
    job = CdnPushJob.create!(:errata => e, :pushed_by => releng_user, :pub_options => {'shadow' => true})

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
      CdnPushJob::PUB_OPTIONS[key].tap{|opt| assert_equal opt[:default], val, "job incorrectly set pub option #{key} = #{val}"}
    end
    assert job.pub_options['shadow'], job.pub_options.inspect
  end

  test 'default push_files for CDN push job' do
    # Advisory containing docker image
    with_docker = Errata.find(21100)
    assert with_docker.has_docker?

    # Non-docker advisory
    without_docker = Errata.find(21009)
    refute without_docker.has_docker?

    assert CdnPushJob.new(:errata => without_docker).valid_pub_options['push_files'][:default],
      'Default push_files for non-docker advisory should be true'

    refute CdnPushJob.new(:errata => with_docker).valid_pub_options['push_files'][:default],
      'Default push_files for docker advisory should be false'

    # Should not be overwritten by default for docker (bz1332774)
    assert CdnPushJob.new(:errata => without_docker).valid_pub_options['push_files'][:default],
      'Default push_files for non-docker advisory should be true'
  end
end
