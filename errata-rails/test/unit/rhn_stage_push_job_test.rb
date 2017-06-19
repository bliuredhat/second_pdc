require 'test_helper'

class RhnStagePushJobTest  < ActiveSupport::TestCase
  test 'rhn stage push job' do

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

    e.stubs(:can_push_rhn_stage?).returns(true)
    job = RhnStagePushJob.create!(:errata => e, :pushed_by => qa_user)
    assert job.can_push?

    job.save!

    assert_equal false, job.pub_options['push_files']
    assert_equal false, job.pub_options['push_metadata']

    job.set_defaults

    assert job.pub_options['push_files'], "push_files not set!"
    assert job.pub_options['push_metadata'], "push_files not set!"
  end

  test 'pdc rhn stage push job' do
    nvr = 'ceph-10.2.3-17.el7cp'
    release_name = 'ReleaseForPDC'
    VCR.use_cassette 'pdc_rhn_stage_push_job' do
     VCR.use_cassettes_for(:pdc_ceph21) do
      e = create_test_rhba(release_name, nvr)

      e.stubs(:can_push_rhn_stage?).returns(true)
      job = RhnStagePushJob.create!(:errata => e, :pushed_by => qa_user)
      assert job.can_push?

      job.save!

      assert_equal false, job.pub_options['push_files']
      assert_equal false, job.pub_options['push_metadata']

      job.set_defaults

      assert job.pub_options['push_files'], "push_files not set!"
      assert job.pub_options['push_metadata'], "push_files not set!"
     end
    end
  end
end
