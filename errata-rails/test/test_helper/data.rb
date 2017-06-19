# Add some data used by tests here, generated on the fly.
module TestData
  def self.lazy_data(name, &block)
    self.send(:define_method, name, lambda{
        varname = "@_lazy_#{name}"
        unless self.instance_variable_defined?(varname)
          self.instance_variable_set(varname, self.instance_eval(&block))
        end
        self.instance_variable_get(varname)
    })
  end

  def self.mkuser(login_name, realname, *roles)
    u = User.new(:login_name => login_name, :realname => realname)
    u.roles.concat(roles.map{|n| Role.find_by_name!(n)})
    u.save!
    u
  end

  def self.lazy_user(varname, login_name, realname, *roles)
    lazy_data("#{varname}_user") {
      TestData.mkuser(login_name, realname, *roles)
    }
  end

  def self.add_test_bug(errata)
    bug = Bug.create!(:package => Package.first, :status => 'MODIFIED',  :short_desc => 'test bug')

    unless errata.release.has_correct_flags?(bug)
      bug.flags = errata.release.blocker_flags.map{|f| "#{f}+"}.join(',')
      bug.save!
    end

    if errata.release.supports_component_acl?
      ReleaseComponent.create(:package => bug.package, :release => errata.release)
    end

    fb = FiledBug.create!(:bug => bug, :errata => errata)
  end

  lazy_user(:devel,     'devel@redhat.com',    'Devel User',               'errata', 'devel')
  lazy_user(:qa,        'qa@redhat.com',       'Qa User',                  'errata', 'qa')
  lazy_user(:secalert,  'secalert_user@redhat.com', 'Secalert User',       'errata', 'secalert', 'createasync')
  lazy_user(:admin,     'admin@redhat.com',    'Admin User',               'errata', 'admin', 'createasync')
  lazy_user(:pm,        'pm@redhat.com',       'Pm User',                  'errata', 'pm')
  lazy_user(:releng,    'releng@redhat.com',   'Release Engineering User', 'errata', 'releng', 'pusherrata')
  lazy_user(:docs,      'docs@redhat.com',     'Docs User',                'errata', 'docs')
  lazy_user(:read_only, 'ro@redhat.com',       'Read Only User',           'errata', 'readonly')
  lazy_user(:signer,    'signer@redhat.com',   'Signer User',              'errata', 'signer')
  lazy_user(:async,     'async@redhat.com',    'Createasync User',         'errata', 'createasync')

  lazy_data(:async_release) {
    Async.create!(:name => 'ASYNC', :description => 'async')
  }

  lazy_data(:rhba_async) do
    e = RHBA.create!(
      :reporter => self.qa_user,
      :synopsis => 'test advisory',
      :product => Product.find_by_short_name!('RHEL'),
      :release => self.async_release,
      :assigned_to => self.qa_user,
      :content => Content.new(
        :topic => 'test',
        :description => 'test',
        :solution => 'fix it'))

    build = BrewBuild.find_by_nvr! 'libogg-1.1.4-3.el6_0.1'
    pv = ProductVersion.find_by_name 'RHEL-6'
    map = ErrataBrewMapping.new(:product_version => pv,
                                :errata => e,
                                :brew_build => build,
                                :package => build.package)

    # Skip rpm version validation here because it will slow down the
    # test performance.  Since this is the test data, so I think can
    # be safely skipped.
    map.skip_rpm_version_validation = true
    map.save!

    TestData.add_test_bug(e)
    RpmdiffRun.schedule_runs(e, self.qa_user)

    e
  end

  def rhba_async_with_discard_delayed_jobs
    #
    # Automatically created delayed jobs should not leak into tests.
    # Wrap above rhba_async and discard any delayed jobs created by it.
    #
    errata = nil
    capture_delayed_jobs {
      errata = rhba_async_without_discard_delayed_jobs
    }
    errata
  end
  alias_method_chain :rhba_async, :discard_delayed_jobs

  def create_test_rhba(release_name, brew_nvr, multi_product = false)
    release = Release.find_by_name(release_name)
    build = BrewBuild.find_by_nvr(brew_nvr)
    content = Content.new(:topic => 'test', :description => 'test', :solution => 'fix it')

    # We'll determine the advisory type based on the release
    klass = RHBA.pdc_maybe(release.is_pdc?)
    rhba = klass.create!(
      :reporter => qa_user,
      :synopsis => 'test 1',
      :product => release.product,
      :release => release,
      :supports_multiple_product_destinations => multi_product,
      :assigned_to => qa_user,
      :content => content)

    TestData.add_test_bug(rhba)

    # (release.product_version_id is obsolete schema, but some tests will fail
    # without it due to old/bad fixture data and I don't want to fix it right now).
    release_version = release.release_versions.first || ProductVersion.find(release.product_version_id)

    if release_version.is_pdc?
      # The PDC way to add a build
      PdcErrataReleaseBuild.create!(
        :pdc_errata_release => PdcErrataRelease.create!(
          :pdc_release => release_version,
          :errata => rhba),
        :brew_build => build)

    else
      # The legacy way to add a build
      ErrataBrewMapping.create!(
        :product_version => release_version,
        :errata => rhba,
        :brew_build => build,
        :package => build.package)

    end

    RpmdiffRun.schedule_runs(rhba, qa_user)
    Delayed::Job.delete_all
    return rhba
  end

  def pass_rpmdiff_runs(errata = nil)
    errata ||= self.rhba_async
    errata.rpmdiff_runs.each {|r| r.update_attribute(:overall_score, 2)}
    errata.rpmdiff_runs.unfinished.reload
  end

  def pass_tps_runs(errata = nil)
    errata ||= self.rhba_async
    good = TpsState.find_by_state 'GOOD'
    run = errata.tps_run
    run.tps_and_rhnqa_jobs.each do |j|
      j.tps_state = good
      j.save!
    end

    run.reload
    errata.reload
  end

  def sign_builds(errata = nil, keyname = 'redhatrelease')
    errata ||= self.rhba_async
    key = SigKey.find_by_name! keyname
    errata.brew_builds.each {|b| b.mark_as_signed(key)}
    errata.brew_files.rpm.update_all(:is_signed => true)
  end

  def rpmdiff_autowaive_rule(options={})
    data = {
      :package_name => BrewBuild.first.package.name,
      :subpackage => 'all',
      :content_pattern => '^foo.*',
      :reason => 'We know this',
      :product_versions => ProductVersion.find_active.first(2),
      :test_id => RpmdiffTest.first.test_id,
      :score => RpmdiffScore::FAILED,
    }.merge(options)

    RpmdiffAutowaiveRule.create!(data)
  end

  # Simulate the fact of result details are waived by an autowaiving rule
  #
  # detail_id: an array of result detail IDs
  # rule: object of an autowaiving rule
  #
  def waive_details_by_rule(detail_ids, rule)
    detail_ids.each do |detail_id|
      RpmdiffAutowaivedResultDetail.create!({
        :result_detail_id => detail_id,
        :autowaive_rule_id => rule.autowaive_rule_id
      })
    end
  end

  def do_push_jobs(errata, job_types, user = User.system)
    klasses = Array.wrap(job_types)
    klasses.each_with_object([]) do |klass, jobs|
      job = klass.create!(:errata => errata, :pushed_by => user, :pub_options => {'push_files'=> true, 'push_metadata' => true})
      job.create_pub_task(Push::PubClient.get_connection)
      job.pub_success!
      jobs << job
    end
  end
end
