require 'test_helper'

class TpsSchedulerTest < ActiveSupport::TestCase
  assert_no_error_logs

  setup do
    Settings.stubs(:enable_tps_cdn).returns(true)
    @rhba = create_test_rhba("RHEL-6.3.0", "autotrace-0.31.1-26.el6")
    @zstream_rhba = create_test_rhba("RHEL-6.5.z", "dracut-004-336.el6_5.1")
    [@rhba, @zstream_rhba].each do |advisory|
      pass_rpmdiff_runs advisory
    end
  end

  def assert_tps_job_count(job_list, expected_channels, expected_repos, expected_channel_names=nil, expected_repo_names=nil)
    job_list_str = job_list.map(&:dist_source).map(&:name).sort
    expected_str = (expected_channels + expected_repos).map(&:name).sort

    # make sure total jobs scheduled are correct
    assert_equal(expected_channels.count + expected_repos.count,
                 job_list.count,
                 [
                  "Amount of repositories/channels expected to be the same with job amount",
                  "Jobs scheduled for:\n  #{job_list_str.join("\n  ")}",
                  "Expected for:\n  #{expected_str.join("\n  ")}"
                 ].join("\n")
                )

    # make sure the total rhn tps jobs are as expected
    assert_equal expected_channels.count, job_list.select{ |job| job.is_rhn? }.count

    # make sure the total cdn tps jobs are as expected
    assert_equal expected_repos.count, job_list.select{ |job| job.is_cdn? }.count
  end

  def assert_channels_repos_match_jobs(job_list, expected_channels, expected_repos)
    job_list.each do |job|
      if job.is_rhn?
        assert expected_channels.include?(job.channel), "unexpected channel: #{job.channel.inspect}"
        # make sure the variant showing in tps job is correct
        assert_equal expected_channels.select{|c| c.id == job.channel.id }.first.variant.rhel_variant, job.variant
      end
      if job.is_cdn?
        assert expected_repos.include?(job.cdn_repo), "unexpected repo: #{job.cdn_repo.inspect}"
      end
    end
  end

  def assert_channels_repos_match_names(expected_names, channels_and_repos)
    assert_equal expected_names.sort, channels_and_repos.map(&:name).sort, "channel or repo names don't match"
  end

  test "schedules correct jobs for errata with sub channels only" do
    @rhba.change_state!(State::QE, qa_user)
    job_list = @rhba.tps_run.all_tps_jobs

    variant = Variant.find_by_name("6Server-optional")
    arches = Arch.where(:name => %w[x86_64 i386 ppc64 s390x])

    expected_channels = PrimaryChannel.where(:variant_id => variant, :arch_id => arches, :has_stable_systems_subscribed => true)
    expected_repos = CdnBinaryRepo.where(:variant_id => variant, :arch_id => arches, :has_stable_systems_subscribed => true)

    # (The name lists are fixture dependent which makes this test more brittle, but it will let us know
    # if fixture data changes in some way, which might be an indication that the test needs to be reviewed)
    expected_channel_names = %w[rhel-i386-server-optional-6 rhel-ppc64-server-optional-6
      rhel-s390x-server-optional-6 rhel-x86_64-server-optional-6]
    expected_repo_names = %w[rhel-6-server-optional-rpms__6Server__ppc64 rhel-6-server-optional-rpms__6Server__x390x
      rhel-6-server-optional-rpms__6Server__x86_64 rhel-6-server-optional-rpms__6Server__i386]

    assert_tps_job_count(job_list, expected_channels, expected_repos)
    assert_channels_repos_match_jobs(job_list, expected_channels, expected_repos)
    assert_channels_repos_match_names(expected_channel_names + expected_repo_names, expected_channels + expected_repos)
  end

  test "schedules correct job amount for errata with base and sub channels and multi products" do
    data = create_rhba_with_multi_product_mappings
    rhba = data[:rhba]

    pass_rpmdiff_runs rhba
    rhba.change_state!(State::QE, qa_user)
    job_list = rhba.tps_run.all_tps_jobs

    all_channels, all_repos, all_channel_names, all_repo_names = [
      data.values_at(:expected_base_channels,:expected_mapped_channels).inject(&:+),
      data.values_at(:expected_base_repos,:expected_mapped_repos).inject(&:+),
      data.values_at(:expected_base_channel_names,:expected_mapped_channel_names).inject(&:+),
      data.values_at(:expected_base_repo_names,:expected_mapped_repo_names).inject(&:+)
    ]

    assert_tps_job_count(job_list, all_channels, all_repos, all_channel_names, all_repo_names)
    assert_channels_repos_match_jobs(job_list, all_channels, all_repos)
    assert_channels_repos_match_names(all_channel_names + all_repo_names, all_channels + all_repos)
  end

  test "schedules correct job amount for errata with layered product" do
    # Set the product version to support cdn so that tps jobs can be scheduled
    pv = ProductVersion.find(153) # RHEL-6-RHEV
    cdn = PushTarget.find_by_name("cdn")
    variant = Variant.find_by_name('6Server-RHEV-Agents')
    pv.update_attributes(:supports_cdn => true)
    ActivePushTarget.create!(:product_version => pv, :who => qa_user, :push_target => cdn)
    VariantPushTarget.create!(:variant => variant, :who => qa_user, :push_target => cdn )

    rhba = create_test_rhba("RHEV-H 6.4.0", "qemu-kvm-rhev-0.12.1.2-2.272.el6")
    pass_rpmdiff_runs rhba
    rhba.change_state!(State::QE, qa_user)
    job_list = rhba.tps_run.all_tps_jobs

    expected_channels = [ Channel.find_by_name("rhel-x86_64-rhev-mgmt-agent-6") ]
    expected_repos = [ CdnRepo.find_by_name("rhel-6-server-rhev-agent-rpms__6Server__x86_64") ]

    assert_tps_job_count(job_list, expected_channels, expected_repos)
  end

  test "errata with ZStream layered product" do
    pv = ProductVersion.find_by_name! "RHEL-5.8.Z-SJIS"
    rhba  = RHBA.create!(:reporter => qa_user,
                         :synopsis => 'test advisory',
                         :product => pv.product,
                         :release => async_release,
                         :assigned_to => qa_user,
                         :content =>
                         Content.new(:topic => 'test',
                                     :description => 'test',
                                     :solution => 'fix it')
                         )
    build = BrewBuild.find_by_nvr 'less-436-9.el5_8.sjis.2'
    ErrataBrewMapping.create!(:product_version => pv,
                              :errata => rhba,
                              :brew_build => build,
                              :package => build.package)
    TestData.add_test_bug(rhba)
    RpmdiffRun.schedule_runs(rhba, qa_user)
    pass_rpmdiff_runs rhba
    rhba.change_state!(State::QE, qa_user)
    jobs = rhba.tps_run.tps_jobs

    channel_names = %w(rhel-i386-server-sjis-5.8.z rhel-ia64-server-sjis-5.8.z rhel-x86_64-server-sjis-5.8.z)
    expected_channels = Push::Rhn.get_channels_for_tps(rhba)
    assert_tps_job_count jobs, expected_channels, [], channel_names
  end

  test "errata with unreleased zstream" do
    expected_jobs = Hash.new{ |hash,key| hash[key] = [] }
    variant_1 = Variant.find_by_name('6Server-6.5.z')
    channel_1  = Channel.find_by_name('rhel-x86_64-server-6')
    cdn_repo_1 = CdnBinaryRepo.find_by_name('rhel-6-server-rpms__6Server__x86_64')

    [[variant_1, channel_1], [variant_1, cdn_repo_1]].each do |variant, dist|
      # the TPS job is not equal to the {Channel|CdnRepo}.variant if the channel/cdn repo is linked
      # to other z-stream variant.
      dist.variant = variant
      expected_jobs[dist.class.model_name.downcase.to_sym] << dist
    end

    @zstream_rhba.change_state!(State::QE, qa_user)
    job_list = @zstream_rhba.tps_run.tps_jobs

    assert_tps_job_count(job_list, expected_jobs[:channel], expected_jobs[:cdnrepo])
    assert_channels_repos_match_jobs(job_list, expected_jobs[:channel], expected_jobs[:cdnrepo])
  end

  test "errata with released zstream" do
    expected_jobs = Hash.new{ |hash,key| hash[key] = [] }
    variant_1 = Variant.find_by_name("6Server-6.5.z")
    channel_1 = Channel.find_by_name("rhel-x86_64-server-6")
    channel_2 = Channel.find_by_name("rhel-x86_64-server-6.5.z")
    cdn_repo_1 = CdnBinaryRepo.find_by_name('rhel-6-server-rpms__6Server__x86_64')
    cdn_repo_2 = CdnBinaryRepo.find_by_name('rhel-6-server-eus-rpms__6_DOT_5__x86_64')

    # Ensure there are no links to any z-stream variants.
    ChannelLink.where(:channel_id => channel_1, :variant_id => variant_1 ).delete_all()
    CdnRepoLink.where(:cdn_repo_id => cdn_repo_1, :variant_id => variant_1 ).delete_all()

    [channel_2, cdn_repo_2].each do |dist|
      # Ensure the tps schedule flag for the channel/cdn repo is on
      dist.update_attributes(:has_stable_systems_subscribed => true)
      expected_jobs[dist.class.model_name.downcase.to_sym] << dist
    end

    @zstream_rhba.change_state!(State::QE, qa_user)
    job_list = @zstream_rhba.tps_run.tps_jobs

    assert_tps_job_count(job_list, expected_jobs[:channel], expected_jobs[:cdnrepo])
    assert_channels_repos_match_jobs(job_list, expected_jobs[:channel], expected_jobs[:cdnrepo])
  end

  # Get a RHEL7 RHBA with one RHEL7 build and one RHEL7-Supplementary build.
  def create_rhel7_rhba_with_multi_version_builds
    e = create_test_rhba("RHEL-7.0.0", "redhat-bookmarks-7-1.el7")
    assert_equal 2, e.release.product_versions.length, 'fixture problem: expected two product versions for RHEL-7.0.0'

    # a build is added already for the first product version.
    # Add one for the other
    ErrataBrewMapping.create!(
      :product_version_id => e.release.product_versions.second.id,
      :errata => e,
      :brew_build => BrewBuild.find_by_nvr!('basesystem-10.0-6.el7'),
      :package => Package.find_by_name!('basesystem')
    )

    e.reload
    e
  end

  def create_rhba_with_multi_product_mappings
    out = {}
    out[:rhba] = create_test_rhba('RHEL-6.3.0', 'sblim-cim-client2-2.1.3-2.el6', true)
    pass_rpmdiff_runs out[:rhba]

    list = [
      {:variant =>'6Server', :arches => %w[x86_64 i386 ppc64 s390x]},
      {:variant =>'6Workstation', :arches => %w[x86_64 i386]},
    ]

    out[:expected_base_channels] = []
    out[:expected_base_repos] = []
    list.each do |l|
      variant = Variant.find_by_name(l[:variant])
      arches = Arch.where(:name => l[:arches])
      out[:expected_base_channels].concat(PrimaryChannel.where(:variant_id => variant, :arch_id => arches, :has_stable_systems_subscribed => true))
      out[:expected_base_repos].concat(CdnBinaryRepo.where(:variant_id => variant, :arch_id => arches, :has_stable_systems_subscribed => true))
    end

    # pulled in by MultiProduct*Map
    out[:expected_mapped_channels] = [Channel.find_by_name!('rhel-x86_64-server-6-rhevh')]
    out[:expected_mapped_repos] = [CdnBinaryRepo.find_by_name!('rhel-6-rhev-s-rpms__6Server-RHEV-S__x86_64')]

    # (The name lists are fixture dependent which makes this test more brittle, but it will let us know
    # if fixture data changes in some way, which might be an indication that the test needs to be reviewed)
    out[:expected_base_channel_names] = %w[rhel-i386-server-6 rhel-ppc64-server-6
      rhel-s390x-server-6 rhel-x86_64-server-6 rhel-i386-workstation-6 rhel-x86_64-workstation-6]
    out[:expected_base_repo_names] = %w[rhel-6-server-rpms__6Server__x86_64 rhel-6-server-rpms__6Server__ppc64
      rhel-6-server-rpms__6Server__s390x rhel-6-server-rpms__6Server__i386]
    out[:expected_mapped_channel_names] = %w[rhel-x86_64-server-6-rhevh]
    out[:expected_mapped_repo_names] = %w[rhel-6-rhev-s-rpms__6Server-RHEV-S__x86_64]

    out
  end

  # Use this to skip any non-TPS transition guards, to simplify tests
  def ignore_non_tps_guards
    StateTransitionGuard.descendants.each do |guard|
      next if guard.to_s =~ /tps/i
      guard.any_instance.stubs(:transition_ok? => true)
    end
  end

  # Bug 1074377
  test "removing a build removes no longer relevant TPS jobs" do
    e = create_rhel7_rhba_with_multi_version_builds

    ignore_non_tps_guards

    job_channels_or_repos = lambda { e.tps_run.tps_jobs.map(&:dist_source).map(&:name).sort }
    old_channels_and_repos = %w[
      rhel-7-desktop-rpms__7Client__x86_64
      rhel-7-for-power-rpms__7Server__ppc64
      rhel-7-for-system-z-rpms__7Server__s390x
      rhel-7-hpc-node-optional-rpms__7ComputeNode__x86_64
      rhel-7-server-rpms__7Server__x86_64
      rhel-7-workstation-rpms__7Workstation__x86_64
      rhel-ppc64-server-7
      rhel-s390x-server-7
      rhel-x86_64-client-7
      rhel-x86_64-hpc-node-7
      rhel-x86_64-server-7
      rhel-x86_64-workstation-7
    ]

    new_channels_and_repos = %w[
      rhel-ppc64-server-supplementary-7
      rhel-x86_64-client-supplementary-7
      rhel-x86_64-hpc-node-supplementary-7
      rhel-x86_64-server-supplementary-7
      rhel-x86_64-workstation-supplementary-7
    ]

    # initially, no jobs (and no run)
    assert_nil e.tps_run

    # move to QA creates jobs for both RHEL7 and RHEL7 Supplementary jobs
    # Supplementary channels/repos are sub-channels so we will merge them into a single TPS job and their base
    # channel/repo is used for the job.
    e.change_state!(State::QE, qa_user)
    assert_equal old_channels_and_repos, job_channels_or_repos.call()

    # move to NEW_FILES, removing the build that has base channels and moving back to QE eliminates the base channel jobs
    e.change_state!(State::NEW_FILES, qa_user)

    e.build_mappings.where(:brew_build_id => BrewBuild.find_by_nvr!('redhat-bookmarks-7-1.el7').id).each(&:obsolete!)
    e.change_state!(State::QE, qa_user)
    assert_equal new_channels_and_repos, job_channels_or_repos.call()
  end

  # Bug 1074377
  test "respinning an advisory should not schedule DistQA jobs" do
    e = create_rhel7_rhba_with_multi_version_builds

    ignore_non_tps_guards

    job_classes = lambda { e.tps_run.all_tps_jobs.map(&:class).map(&:name).sort.uniq }

    # initially, no jobs (and no run)
    assert_nil e.tps_run

    # move to QA creates Rhn jobs (no RhnQa)
    e.change_state!(State::QE, qa_user)
    assert_equal %w[CdnTpsJob RhnTpsJob], job_classes.call()

    # move to NEW_FILES, removing the build for supplementary and moving back to QE should not schedule
    # RhnQa jobs (or any other new class)
    e.change_state!(State::NEW_FILES, qa_user)
    e.build_mappings.where(:brew_build_id => BrewBuild.find_by_nvr!('basesystem-10.0-6.el7').id).each(&:obsolete!)
    e.change_state!(State::QE, qa_user)
    assert_equal %w[CdnTpsJob RhnTpsJob], job_classes.call()
  end

  # Bug 1076284
  [[true,false], [false,true]].each do |multi_product_support|
    test "setting multi product support #{multi_product_support.first} then #{multi_product_support.second} schedules appropriate jobs" do
      data = create_rhba_with_multi_product_mappings
      rhba = data[:rhba]
      pass_rpmdiff_runs rhba

      base_channels, base_repos, base_channel_names, base_repo_names = data.values_at(
        :expected_base_channels,
        :expected_base_repos,
        :expected_base_channel_names,
        :expected_base_repo_names
      )

      all_channels, all_repos, all_channel_names, all_repo_names = [
        base_channels + data[:expected_mapped_channels],
        base_repos + data[:expected_mapped_repos],
        base_channel_names + data[:expected_mapped_channel_names],
        base_repo_names + data[:expected_mapped_repo_names],
      ]

      assert_jobs = lambda do |channels, channel_names, repos, repo_names|
        job_list = rhba.tps_run.all_tps_jobs
        assert_tps_job_count(job_list, channels, repos, channel_names, repo_names)
        assert_channels_repos_match_jobs(job_list, channels, repos)
        assert_channels_repos_match_names(channel_names + repo_names, channels + repos)
      end

      assert_multi_product_jobs = lambda do
        assert_jobs.call(all_channels, all_channel_names, all_repos, all_repo_names)
      end

      assert_no_multi_product_jobs = lambda do
        assert_jobs.call(base_channels, base_channel_names, base_repos, base_repo_names)
      end

      assert_relevant_jobs = lambda do |multi_product|
        multi_product ? assert_multi_product_jobs.call() : assert_no_multi_product_jobs.call()
      end

      # move to QA with the first value and check the resulting jobs...
      rhba.update_attribute(:supports_multiple_product_destinations, multi_product_support.first)
      rhba.reload
      rhba.change_state!(State::QE, qa_user)
      assert_relevant_jobs.call(multi_product_support.first)

      # now move back to NEW_FILES, adjust multi-product support, back to QE, and check jobs again
      rhba.change_state!(State::NEW_FILES, qa_user)
      rhba.update_attribute(:supports_multiple_product_destinations, multi_product_support.second)
      rhba.reload
      rhba.change_state!(State::QE, qa_user)

      assert_relevant_jobs.call(multi_product_support.second)
    end
  end

  # Bug 1084442
  test "group sub dist repos by their parents" do

    # both sub channels are belong to the same base channel
    # 'rhel-x86_64-server-7', their base channel will be used for
    # TPS job
    sub_channels_for_7server = %w{
      rhel-x86_64-server-optional-7
      rhel-x86_64-server-supplementary-7}

    # always choose the base channel for TPS job if available
    sub_channels_for_7client = %w{
      rhel-x86_64-client-7
      rhel-x86_64-client-optional-7
      rhel-x86_64-client-supplementary-7}

    # since it is only 1 sub channel for 7Workstation, it will
    # be used for TPS job. No grouping is required.
    sub_channels_for_7ws = %w{
      rhel-x86_64-workstation-supplementary-7}

    sub_repo_for_7server = %w{
      rhel-7-server-supplementary-rpms__7Server__x86_64
      rhel-7-server-rhev-mgmt-agent-rpms__7Server__x86_64}

    expected_channels_name = %w{
      rhel-x86_64-server-7
      rhel-x86_64-client-7
      rhel-x86_64-workstation-supplementary-7}

    expected_repos_name = %w{rhel-7-server-rpms__7Server__x86_64}

    expected_channels = Channel.where(:name => expected_channels_name).to_a
    expected_repos = CdnRepo.where(:name => expected_repos_name).to_a

    brew = BrewBuild.first
    rpm = BrewRpm.first
    variant = Variant.first
    arch = Arch.first

    Push::Rhn.stubs(:rpm_channel_map).multiple_yields(
      [brew, rpm, variant, arch, Channel.where(:name => sub_channels_for_7server), []],
      [brew, rpm, variant, arch, Channel.where(:name => sub_channels_for_7client), []],
      [brew, rpm, variant, arch, Channel.where(:name => sub_channels_for_7ws), []]
    )

    Push::Cdn.stubs(:rpm_repo_map).multiple_yields(
      [brew, rpm, variant, arch, CdnRepo.where(:name => sub_repo_for_7server), []]
    )

    @rhba.change_state!(State::QE, qa_user)
    job_list = @rhba.tps_run.all_tps_jobs

    assert_tps_job_count(job_list, expected_channels , expected_repos)
    assert_channels_repos_match_jobs(job_list, expected_channels, expected_repos)
  end

  # Bug 1145951
  test "schedule tps job not fail if channels or repos are orphan" do
    rhel = Product.find_by_short_name!('RHEL')
    rhel_6_5 = ProductVersion.find_by_name!('RHEL-6.5.z')
    rhel_rel = RhelRelease.find_by_name!('RHEL-6.5.Z')
    arch = Arch.find_by_name!('x86_64')

    # create a test rhel variant without base channels and base cdn repos
    # (empty variant)
    rhel_variant = Variant.create!(
      { :name => '6TestServer-6.5.z',
        :product => rhel,
        :product_version => rhel_6_5,
        :tps_stream => 'RHEL-6.5-Z-Server',
        :rhel_release => rhel_rel,})

    # create a test sub variant
    ha_variant = Variant.create!(
      { :name => '6TestServer-HighAvailability-6.5.z',
        :product => rhel,
        :product_version => rhel_6_5,
        :rhel_release => rhel_rel,
        :rhel_variant => rhel_variant,})

    # create and attach 2 channels and 2 cdn repos to the created sub variant
    eus_channel = EusChannel.create!(
      { :name => 'rhel-x86_64-test_server-ha-6.5.z',
        :product_version => rhel_6_5,
        :arch => arch,
        :variant => ha_variant,
        :has_stable_systems_subscribed => true,})

    ll_channel = LongLifeChannel.create!(
      { :name => 'rhel-x86_64-test_server-ha-6.5.aus',
        :product_version => rhel_6_5,
        :arch => arch,
        :variant => ha_variant,
        :has_stable_systems_subscribed => true,})

    eus_cdn_repo = CdnBinaryRepo.create!(
      { :name => 'rhel-ha-for-rhel-6-test_server-eus-rpms__6_DOT_5__x86_64',
        :arch => arch,
        :variant => ha_variant,
        :has_stable_systems_subscribed => true,})

    ll_cdn_repo = CdnBinaryRepo.create!(
      { :name => 'rhel-ha-for-rhel-6-test_server-aus-rpms__6_DOT_5__x86_64',
        :arch => arch,
        :variant => ha_variant,
        :has_stable_systems_subscribed => true,})

    expected_channels = [eus_channel, ll_channel]
    expected_cdn_repos = [eus_cdn_repo, ll_cdn_repo]

    brew = BrewBuild.first
    rpm = BrewRpm.first
    Push::Rhn.stubs(:rpm_channel_map).multiple_yields(
      [brew, rpm, ha_variant, arch, expected_channels, []])

    Push::Cdn.stubs(:rpm_repo_map).multiple_yields(
      [brew, rpm, ha_variant, arch, expected_cdn_repos, []]
    )

    @zstream_rhba.change_state!(State::QE, qa_user)
    job_list = @zstream_rhba.tps_run.all_tps_jobs

    # should creates 4 tps jobs (no grouping for orphan channels and cdn repos)
    assert_tps_job_count(job_list, expected_channels , expected_cdn_repos)
    assert_channels_repos_match_jobs(job_list, expected_channels, expected_cdn_repos)
  end

  # Used to test various cases for bug 1168893
  def tps_respin_test(args)
    e = args.delete(:errata) || Errata.find(19828)

    get_jobs = lambda do
      e.reload.tps_run.tps_jobs.inject({}) {|h,job|
        h.merge!(job.channel.name => [job.tps_state,job.started])
      }
    end

    original_jobs = get_jobs.call()

    e.change_state!(State::NEW_FILES, qa_user)

    last_comment = e.reload.comments.last.id

    args[:respin].call(e)

    e.reload.change_state!(State::QE, qa_user)

    new_jobs = get_jobs.call()

    unaffected = []
    rescheduled = []
    removed = []
    added = []

    original_jobs.each do |channel,state|
      if new_jobs[channel] == state
        unaffected << channel
      elsif new_jobs[channel]
        rescheduled << channel
      else
        removed << channel
      end
    end

    new_jobs.each do |channel,state|
      if !original_jobs[channel]
        added << channel
      end
    end

    check = lambda do |expected_key,actual|
      assert_equal_or_diff args.fetch(expected_key, []).sort.join("\n"),
        actual.sort.join("\n"),
        "Expected and actual values differ for '#{expected_key}'"
    end

    check.call(:unaffected, unaffected)
    check.call(:rescheduled, rescheduled)
    check.call(:removed, removed)
    check.call(:added, added)

    created_comments = e.reload.comments.where('id > ?', last_comment).map(&:text)
    tps_comment = created_comments.select{|t| t.include?('TPS')}

    if expected=args[:comment]
      assert_equal 1, tps_comment.length, created_comments.join(', ')
      assert_equal expected, tps_comment.first
    else
      assert_equal [], tps_comment.to_a
    end
  end

  test 'removing a build from one PV only reschedules those jobs' do
    tps_respin_test(
      :respin => lambda{|e|
        # Remove this one build from RHEL-6.6.z
        to_delete = e.build_mappings.joins(:brew_build).
          where(:brew_builds => {:nvr => 'openscap-1.0.10-2.el6'})
        assert_equal 1, to_delete.length
        to_delete.first.obsolete!
      },

      # should leave RHEL 7 jobs alone and reschedule (most) RHEL 6 jobs
      :unaffected => %w[
        rhel-ppc64-server-7
        rhel-s390x-server-7
        rhel-x86_64-client-optional-7
        rhel-x86_64-hpc-node-6
        rhel-x86_64-hpc-node-7
        rhel-x86_64-server-7
        rhel-x86_64-workstation-optional-7
      ],
      :rescheduled => %w[
        rhel-i386-client-6
        rhel-i386-server-6
        rhel-i386-workstation-6
        rhel-ppc64-server-6
        rhel-s390x-server-6
        rhel-x86_64-client-6
        rhel-x86_64-server-6
        rhel-x86_64-workstation-6
      ],
      :comment => '8 TPS jobs rescheduled due to changed builds.')
  end

  test 'removing all builds from one PV removes those jobs' do
    tps_respin_test(
      :respin => lambda{|e|
        to_delete = e.build_mappings.where(
          :product_version_id => ProductVersion.find_by_name!('RHEL-6.6.z'))
        assert_equal 2, to_delete.length
        to_delete.each(&:obsolete!)
      },

      :removed => %w[
        rhel-i386-client-6
        rhel-i386-server-6
        rhel-i386-workstation-6
        rhel-ppc64-server-6
        rhel-s390x-server-6
        rhel-x86_64-client-6
        rhel-x86_64-hpc-node-6
        rhel-x86_64-server-6
        rhel-x86_64-workstation-6
      ],
      :unaffected => %w[
        rhel-ppc64-server-7
        rhel-s390x-server-7
        rhel-x86_64-client-optional-7
        rhel-x86_64-hpc-node-7
        rhel-x86_64-server-7
        rhel-x86_64-workstation-optional-7
      ],

      :comment => '9 TPS jobs removed due to changed builds.')
  end

  test 'adding a build to one PV only reschedules those jobs' do
    tps_respin_test(
      :respin => lambda{|e|
        bb = BrewBuild.find_by_nvr!('sos-3.0-23.el7_0.11')
        m = ErrataBrewMapping.new(
          :errata => e,
          :brew_build => bb,
          :package => bb.package,
          :product_version => ProductVersion.find_by_name!('RHEL-7.0.Z'))

        m.save!

        # ignore rpmdiff scheduling
        e.class.any_instance.stubs(:rpmdiff_finished? => true)
      },

      # Jobs for most RHEL 7 channels/repos are rescheduled, but not
      # optional because sos is not shipped there (according to
      # product listings)
      :unaffected => %w[
        rhel-i386-client-6
        rhel-i386-server-6
        rhel-i386-workstation-6
        rhel-ppc64-server-6
        rhel-s390x-server-6
        rhel-x86_64-client-6
        rhel-x86_64-client-optional-7
        rhel-x86_64-hpc-node-6
        rhel-x86_64-server-6
        rhel-x86_64-workstation-6
        rhel-x86_64-workstation-optional-7
      ],
      :rescheduled => %w[
        rhel-ppc64-server-7
        rhel-s390x-server-7
        rhel-x86_64-hpc-node-7
        rhel-x86_64-server-7
      ],
      :comment => '4 TPS jobs rescheduled due to changed builds.')
  end

  test 'adding builds to every PV reschedules expected jobs' do
    tps_respin_test(
      :respin => lambda{|e|
        [['sos-3.0-23.el7_0.11', 'RHEL-7.0.Z'],
         ['kernel-2.6.32-532.el6', 'RHEL-6.6.z']].each do |nvr,pv_name|
          bb = BrewBuild.find_by_nvr!(nvr)
          m = ErrataBrewMapping.new(
            :errata => e,
            :brew_build => bb,
            :package => bb.package,
            :product_version => ProductVersion.find_by_name!(pv_name))

          m.save!

          # ignore rpmdiff scheduling
          e.class.any_instance.stubs(:rpmdiff_finished? => true)
        end
      },

      # The added RHEL 7 build is not shipped to these
      :unaffected => %w[
        rhel-x86_64-client-optional-7
        rhel-x86_64-workstation-optional-7
      ],

      :rescheduled => %w[
        rhel-ppc64-server-7
        rhel-s390x-server-7
        rhel-x86_64-hpc-node-7
        rhel-x86_64-server-7

        rhel-i386-client-6
        rhel-i386-server-6
        rhel-i386-workstation-6
        rhel-ppc64-server-6
        rhel-s390x-server-6
        rhel-x86_64-client-6
        rhel-x86_64-hpc-node-6
        rhel-x86_64-server-6
        rhel-x86_64-workstation-6
      ],
      :comment => '13 TPS jobs rescheduled due to changed builds.')
  end

  test 'removing a build from all PVs reschedules expected jobs' do
    tps_respin_test(
      :respin => lambda{|e|
        to_delete = e.build_mappings.joins(:brew_build).
          where(:brew_builds => {:nvr => %w[
            openscap-1.0.10-2.el6 anaconda-19.31.123-1.el7
          ]})
        assert_equal 2, to_delete.length
        to_delete.each(&:obsolete!)
      },

      # only ruby is being shipped here, which is not being removed
      :unaffected => %w[
        rhel-x86_64-hpc-node-6
      ],

      :rescheduled => %w[
        rhel-ppc64-server-7
        rhel-s390x-server-7
        rhel-x86_64-client-optional-7
        rhel-x86_64-hpc-node-7
        rhel-x86_64-server-7
        rhel-x86_64-workstation-optional-7

        rhel-i386-client-6
        rhel-i386-server-6
        rhel-i386-workstation-6
        rhel-ppc64-server-6
        rhel-s390x-server-6
        rhel-x86_64-client-6
        rhel-x86_64-server-6
        rhel-x86_64-workstation-6
      ],

      :comment => '14 TPS jobs rescheduled due to changed builds.')
  end

  # Bug 1208791
  test 'adding a build to fast track advisory reschedules expected jobs' do
    errata = create_test_rhba("FAST6.7", "sblim-cim-client2-2.1.3-2.el6")
    # ignore rpmdiff scheduling
    errata.class.any_instance.stubs(:rpmdiff_finished? => true)
    errata.change_state!(State::QE, qa_user)
    job_list = errata.tps_run.all_tps_jobs

    tps_respin_test(
      :errata => errata,
      :respin => lambda{|e|
        bb = BrewBuild.find_by_nvr!("libogg-1.1.4-3.el6_0.1")
        m = ErrataBrewMapping.new(
          :errata => e,
          :brew_build => bb,
          :package => bb.package,
          :product_version => ProductVersion.find_by_name!('RHEL-6'))

        m.save!
      },
      :added => %w[
        rhel-i386-client-fastrack-6
        rhel-x86_64-client-fastrack-6
        rhel-x86_64-hpc-node-fastrack-6
      ],
      :unaffected => %w[],
      # All existing jobs are rescheduled
      :rescheduled => job_list.all.map(&:channel).map(&:name),
      :comment => '3 TPS jobs scheduled, 6 TPS jobs rescheduled due to changed builds.')
  end

  # Bug 1386428
  test 'eus channels should not run on MAIN stream' do
    # Set the rhel variant with -MAIN- stream
    rhel_variant = Variant.find_by_name!('6Server-6.5.z')
    rhel_variant.update_attribute(:tps_stream, 'RHEL-6.5-Main-Server')

    # find the channels and the cdn repos belonging to the rhel variant
    eus_channel = EusChannel.find_by_name!('rhel-x86_64-server-6.5.z')
    ll_channel = LongLifeChannel.find_by_name!('rhel-x86_64-server-6.5.aus')
    eus_cdn_repo = CdnBinaryRepo.find_by_name!('rhel-6-server-eus-rpms__6_DOT_5__x86_64')

    # Set above channels and repos with 'has_stable_systems_subscribed' true
    [eus_channel, ll_channel, eus_cdn_repo].each do |obj|
      obj.update_attribute(:has_stable_systems_subscribed, true)
    end

    Push::Rhn.stubs(:rpm_channel_map).multiple_yields(
      [nil, nil, rhel_variant, nil, [eus_channel, ll_channel], []])

    Push::Cdn.stubs(:rpm_repo_map).multiple_yields(
      [nil, nil, rhel_variant, nil, [eus_cdn_repo], []]
    )

    @zstream_rhba.change_state!(State::QE, qa_user)
    job_list = @zstream_rhba.tps_run.all_tps_jobs
    assert_equal(0, job_list.count)
  end

  test 'layered product running on eus rhel product should not run on MAIN stream' do
    rhel_6_5 = ProductVersion.find_by_name!('RHEL-6.5.z')

    # Set the rhel variant with -MAIN- stream
    rhel_variant = Variant.find_by_name!('6Server-6.5.z')
    rhel_variant.update_attribute(:tps_stream, 'RHEL-6.5-Main-Server')
    rhscl_variant = Variant.find_by_name!('6Server-RHSCL-1.2-6.5.z')

    # find the channel and the cdn repo belonging to the layered product variant
    rhscl_primary_channel = PrimaryChannel.find_by_name!('rhel-x86_64-server-6.5.z-rhscl-1.2')
    rhscl_primary_cdn_repo = CdnBinaryRepo.find_by_name!('rhel-server-rhscl-6-eus-rpms__6_DOT_5__x86_64')

    # Set above channels and repos with 'has_stable_systems_subscribed' true
    [rhscl_primary_channel, rhscl_primary_cdn_repo].each do |obj|
      obj.update_attribute(:has_stable_systems_subscribed, true)
    end

    # Disable the product version RHEL-6.5.z
    rhel_6_5.update_attribute(:enabled, 0)

    Push::Rhn.stubs(:rpm_channel_map).multiple_yields(
      [nil, nil, rhscl_variant, nil, [rhscl_primary_channel], []])
    Push::Cdn.stubs(:rpm_repo_map).multiple_yields(
      [nil, nil, rhscl_variant, nil, [rhscl_primary_cdn_repo], []]
    )

    @zstream_rhba.change_state!(State::QE, qa_user)
    job_list = @zstream_rhba.tps_run.all_tps_jobs
    assert_equal(0, job_list.count)
  end

  test 'channel or cdn repos should match with stream' do
    rhel_6_5 = ProductVersion.find_by_name!('RHEL-6.5.z')

    # Set the rhel variant with -MAIN- stream
    rhel_variant = Variant.find_by_name!('6Server-6.5.z')
    rhel_variant.update_attribute(:tps_stream, 'RHEL-6.5-Main-Server')
    rhscl_variant = Variant.find_by_name!('6Server-RHSCL-1.2-6.5.z')

    # find the channel and the cdn repo belonging to the rhel variant
    rhel_primary_channel = PrimaryChannel.find_by_name!('rhel-x86_64-server-6')
    eus_channel = EusChannel.find_by_name!('rhel-x86_64-server-6.5.z')
    eus_cdn_repo = CdnBinaryRepo.find_by_name!('rhel-6-server-eus-rpms__6_DOT_5__x86_64')

    # find the channel and the cdn repo belonging to the layered product variant
    rhscl_primary_channel = PrimaryChannel.find_by_name!('rhel-x86_64-server-6.5.z-rhscl-1.2')
    rhscl_primary_cdn_repo = CdnBinaryRepo.find_by_name!('rhel-server-rhscl-6-eus-rpms__6_DOT_5__x86_64')

    assert(!rhel_primary_channel.invalid_on_main_stream?, "Packages of primary channel #{rhel_primary_channel.name} can run on main stream")
    assert(eus_channel.invalid_on_main_stream?, "Packages of eus channel #{eus_channel.name} cannot run on main stream")
    assert(eus_cdn_repo.invalid_on_main_stream?, "Packages of eus cdn repo #{eus_cdn_repo.name} cannot run on main stream")

    # Channel/Repo belonging to the z-stream product can run on the main
    # stream if the base rhel product on the standard z-stream process
    assert(!rhscl_primary_channel.invalid_on_main_stream?)
    assert(!rhscl_primary_cdn_repo.invalid_on_main_stream?)

    rhscl_primary_channel.reload
    rhscl_primary_cdn_repo.reload
    # Disable the product version RHEL-6.5.z
    rhel_6_5.update_attribute(:enabled, 0)

    # Channel/Repo belonging to the z-stream product cannot run on the main
    # stream if the base rhel product is out of the standard z-stream process
    assert(rhscl_primary_channel.invalid_on_main_stream?)
    assert(rhscl_primary_cdn_repo.invalid_on_main_stream?)
  end
end
