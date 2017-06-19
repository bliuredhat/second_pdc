require 'test_helper'

class ErrataServiceTest < ActiveSupport::TestCase

  setup do
    @service = ErrataService.new
    @rhn_cdn_advisory = Errata.find(10836)
  end

  # This should help catch any marshalling errors.
  # Do an XMLRPC marshal/unmarshal round trip.
  def marshal_round_trip(resp)
    m = XMLRPC::Marshal.dump_response(resp)
    XMLRPC::Marshal.load_response(m)
  end

  # Bug 609752
  test "getRHNChannels" do
    arch = Arch.find_by_name('i386')
    advisory = Errata.find(11105)

    assert @service.getRHNChannels('XXZADinvalid', '6AS', arch.name).empty?

    RPCLOG.expects(:warn)
    assert @service.getRHNChannels(advisory.id, '6AS', Arch.find_by_name('i686').name).empty?

    Push::Rhn.stubs(:channels_for_errata).with(
      kind_of(Errata), instance_of(Variant), instance_of(Arch)).returns(FastTrackChannel.last(2))
    names = @service.getRHNChannels(advisory.id, Variant.last.name, arch.name)
    assert names.any?
  end

  #
  # Test get_errata_text method
  #
  test "get_errata_text method responds as expected" do
    txt = @service.get_errata_text(rhba_async.id)
    # The response is a big chunk of text.
    # Ensure it has some of the expected content.
    # These are section headings.
    assert_match('Red Hat Bug Fix Advisory', txt)
    assert_match('Summary:', txt)
    assert_match('Description:', txt)
    assert_match('Solution:', txt)
  end

  #
  # Make sure getErrataStatsByGroup works okay
  # See bug 709735
  #
  test "getErrataStatsByGroup(group_name) works and returns the expected data" do
    # NB: This is the expected response using fixture data as at 14-Jun-2011.
    # If we refresh the fixture data then this will probably need to be updated.
    # Ideally this could be derived from the data, but this should be good enough.
    group_to_test = 'RHEL-5.7.0'
    expected_result = [
      { :status => "DOC_APPROVE",    :count => 1 },
      { :status => "DOC_DISAPPROVE", :count => 4 },
      { :status => "NEW_FILES",      :count => 2 },
      { :status => "QE",             :count => 2 },
      { :status => "REL_PREP",       :count => 1 },
      { :status => "TOTAL",          :count => 5 },
    ].sort_by{ |x| x[:status] }

    expected_result.sort! {|a,b| a[:status] <=> b[:status]}
    response = @service.getErrataStatsByGroup(group_to_test)

    sorted_response = response.sort_by{ |x| x[:status] }


    # Did we get the expected response
    assert_equal expected_result, sorted_response

    # marshal_round_trip will turn symbols into strings.
    # Hash#stringify_keys is defined by Rails and is just what we need here...
    expected_result_stringified = expected_result.map{ |h| h.stringify_keys }

    # Does it marshal okay? Should catch problems like in bug 709735.
    assert_equal expected_result_stringified, marshal_round_trip(sorted_response)
  end

  test "get_advisory_list_condition querying for one particular advisory" do
    assert @service.send(:get_advisory_list, {'id' => Errata.last.id + 1}).empty?

    result = @service.send(:get_advisory_list, {'id' => Errata.last.id})
    assert_equal 1, result.count
    assert result[0].has_value?(Errata.last.id)
  end

  test "get_advisory_list_conditions querying for groups and release" do
    expected = Release.find_by_name(Release.last.name)
    result = @service.send(:get_advisory_list_conditions, {'release' => expected.name})
    assert result[:conditions].include?(expected)
  end

  test "get_advisory_list_conditions querying for single product" do
    rhel = Product.find_by_short_name("RHEL")
    result = @service.send(:get_advisory_list_conditions, 'product' => rhel.short_name)
    assert result[:conditions].flatten.include?(rhel)
  end

  test "get_advisory_list_conditions querying for multiple products" do
    rhel = Product.find_by_short_name("RHEL")
    rhcs = Product.find_by_short_name("RHCS")
    products = [rhel.short_name, rhcs.short_name]

    result = @service.send(:get_advisory_list_conditions, 'product' => products)

    conditions = result[:conditions].flatten
    assert conditions.include?(rhel)
    assert conditions.include?(rhcs)
  end

  test "get_advisory_list for ASYNC with particular product versions" do
    get_list = lambda do |args|
      @service.send(:get_advisory_list, args)
    end

    all_async = get_list[{'group' => 'ASYNC'}]

    # Should have been able to find at least a few...
    assert all_async.count > 10

    # Now filter by a few product versions
    pv = %w[RHEL-6 RHEL-6-JBEAP-6]
    filtered_async = get_list[{'group' => 'ASYNC', 'product_version' => pv}]

    # Should have found less, but still some
    assert filtered_async.count > 0
    assert filtered_async.count < all_async.count

    filtered_async.each do |found|
      # What we found should be a subset of the unfiltered set
      assert all_async.include?(found), found.inspect

      # Every advisory we found should have at least one build in one of the
      # requested product versions
      found_pv = Errata.find(found[:errata_id]).product_versions.map(&:name)
      assert pv.any?{ |x| found_pv.include?(x) }, found.inspect
    end
  end

  test "get_advisory_list_conditions raises error on invalid parameters" do
    ['release',
     'errata_type',
     'statuses',
     'qe_owner',
     'qe_group',
     'pkg_owner',
     'package',
     'product_version',
    ].each do |k|
      assert_raises(StandardError) {
        val = 'invalid'
        val = ['invalid'] if 'statuses' == k
        @service.send(:get_advisory_list_conditions, {k => val})
      }
    end

    assert_raises(StandardError) {
      @service.send(:get_advisory_list_conditions, {'product' => [1]})
    }
  end

  test "get_advisory_list raises error if too many errata requested" do
    Settings.max_advisory_list_items = 50

    assert_raises(FetchLimitExceededError) do
      @service.get_advisory_list({})
    end
  end

  test "get_advisory_list limit is reduced when requesting more data" do
    Settings.max_advisory_list_items = 160

    # Fix scope to not fail when more fixtures are added
    LegacyErrata.with_scope(:find => {:conditions => 'errata_main.id <= 19829'}) do
      errata_count = LegacyErrata.where(:is_valid => 1).count

      test_params = lambda do |params,expected_limit|
        error = assert_raises(FetchLimitExceededError) do
          @service.get_advisory_list(params)
        end
        assert_equal(
          "LegacyErrata count #{errata_count} exceeds internal limit of #{expected_limit}",
          error.message)
      end
      test_params.call({'files' => true}, 40)
      test_params.call({'report' => true}, 80)
      test_params.call({'can_push' => true}, 20)

      test_params.call(
        {'files' => true, 'report' => true, 'can_push' => true},
        2)
    end
  end

  test "get_advisory_list paginates OK" do
    Settings.max_advisory_list_items = 8000

    all_results = @service.get_advisory_list({})
    assert all_results.length > 50, 'sanity check failed: fixtures broken?'

    paged_results = []
    read_pages = 0
    per_page = 13
    MAX_PAGES = 200

    get_next_page = lambda do
      @service.get_advisory_list({'page' => read_pages+1, 'per_page' => per_page})
    end

    until (r = get_next_page.call).empty?
      paged_results.concat(r)
      read_pages = read_pages + 1
      # avoid infinite loop if it's broken
      assert read_pages < MAX_PAGES
    end

    assert_equal read_pages, (all_results.length.to_f/per_page).ceil
    assert_equal all_results, paged_results
  end

  test "get_advisory_list query by time" do
    errata = LegacyErrata.last
    oldest_errata = LegacyErrata.first

    #
    # Test query parameters who query greater than dates.
    #
    #   * keep the old date
    #   * overwrite it with a date 10 minutes ago
    #   * query for this date so we expect only the errata we've changed
    #     to return
    #   * query for advisories which have been created exactly now,
    #     which should be empty
    #   * restore the old date
    #
    {'issue_date'  => 'issue_date_gt',
     'update_date' => 'update_date_gt',
     'created_at'  => 'created_at',
     'updated_at'  => 'updated_at'}.each do |attr_name, method_name|
      olddate = errata.send(attr_name)
      time = 10.minutes.ago
      errata.update_attribute(attr_name, time)

      result = @service.get_advisory_list({method_name => time - 1})
      assert_equal 1, result.count
      assert result.first.has_value? errata.id

      assert @service.get_advisory_list({method_name => DateTime.now}).empty?

      errata.send("#{attr_name}=", olddate)
    end

    #
    # Test the less than equal dates. We pick the oldest errata and
    # query for it's issue date. Since it's the oldest with a 10 minutes
    # timeframe, we most likely will get only one errata back.
    #
    {'issue_date'  => 'issue_date_lte',
     'update_date' => 'update_date_lte'}.each do |attr_name, method_name|
      querydate = oldest_errata.send(attr_name) + 10.minutes
      result = @service.get_advisory_list({method_name => querydate})
      assert_equal 1, result.count
      assert result.first.has_value? oldest_errata.id
      assert result.first.has_value? oldest_errata.synopsis
    end
  end

  # New for bug 1006193. Previously it returned [].
  test "get_advisory_rhn_file_list errors if errata not found" do
    exception = assert_raises(RuntimeError) { @service.get_advisory_rhn_file_list('blah') }
    assert_equal "Can't find errata 'blah'", exception.message
  end

  test 'get_advisory_rhn_file_list baseline test' do
    with_baselines('xmlrpc', /get_advisory_rhn_file_list_(\d+)\.json/) do |file,id|
      canonicalize_json @service.get_advisory_rhn_file_list(id).to_json
    end
  end

  test 'get_advisory_rhn_nonrpm_file_list baseline test' do
    # Only use cached product listings
    Brew.any_instance.stubs(:getProductListings => {})

    with_baselines('xmlrpc', /get_advisory_rhn_nonrpm_file_list_(\d+)\.json/) do |file,id|
      canonicalize_json @service.get_advisory_rhn_nonrpm_file_list(id).to_json
    end
  end

  test 'get_advisory_cdn_file_list baseline test' do
    with_baselines('xmlrpc', /get_advisory_cdn_file_list_(\d+)\.json/) do |file,id|
      canonicalize_json @service.get_advisory_cdn_file_list(id).to_json
    end
  end

  test 'get_advisory_cdn_nonrpm_file_list baseline test' do
    # Only use cached product listings
    Brew.any_instance.stubs(:getProductListings => {})

    with_baselines('xmlrpc', /get_advisory_cdn_nonrpm_file_list_(\d+)\.json/) do |file,id|
      canonicalize_json @service.get_advisory_cdn_nonrpm_file_list(id).to_json
    end
  end

  def get_advisory_cdn_file_list_test(args)
    advisory_name = '2012:0987'
    expected_nvr = 'sblim-cim-client2-2.1.3-2.el6'
    expected_rpm = 'sblim-cim-client2-2.1.3-2.el6.noarch.rpm'
    expected_repos = args[:expected_repos] || raise(ArgumentError, 'missing :expected_repos')

    Errata.find(13147).update_attribute(:supports_multiple_product_destinations, args[:supports_multiple_product_destinations] || false)
    result = @service.get_advisory_cdn_file_list(advisory_name, args[:shadow])
    assert_kind_of Hash, result
    assert_equal expected_repos.sort, result[expected_nvr]['rpms'][expected_rpm].sort
  end

  test "get_advisory_cdn_file_list ignores mappings when multi products disabled" do
    # As well as ignoring the mappings, it should not attempt to fetch
    # product listings for the mapped products.
    # (Deleting the existing cache(s) so they can't be used.)
    Brew.any_instance.expects(:getProductListings).never
    bb = BrewBuild.find_by_nvr!('sblim-cim-client2-2.1.3-2.el6')
    ProductListingCache.where(
      :brew_build_id => bb,
      :product_version_id => MultiProductCdnRepoMap.pluck('distinct destination_product_version_id')
    ).delete_all

    get_advisory_cdn_file_list_test(
      :supports_multiple_product_destinations => false,
      :expected_repos => %w{
        rhel-6-server-rpms__6Server__x86_64
        rhel-6-server-rpms__6Server__i386
        rhel-6-server-rpms__6Server__ppc64
        rhel-6-server-rpms__6Server__s390x
      }
    )
  end

  test "get_advisory_cdn_file_list respects mappings when multi products enabled" do
    get_advisory_cdn_file_list_test(
      :supports_multiple_product_destinations => true,
      :expected_repos => %w{
        rhel-6-server-rpms__6Server__x86_64
        rhel-6-server-rpms__6Server__i386
        rhel-6-server-rpms__6Server__ppc64
        rhel-6-server-rpms__6Server__s390x
        rhel-6-rhev-s-rpms__6Server-RHEV-S__x86_64
      }
    )
  end

  test "get_advisory_cdn_file_list respects mappings when multi products enabled for shadow push" do
    get_advisory_cdn_file_list_test(
      :supports_multiple_product_destinations => true,
      :shadow => true,
      :expected_repos => %w{
        shadow-rhel-6-server-rpms__6Server__x86_64
        shadow-rhel-6-server-rpms__6Server__i386
        shadow-rhel-6-server-rpms__6Server__ppc64
        shadow-rhel-6-server-rpms__6Server__s390x
        shadow-rhel-6-rhev-s-rpms__6Server-RHEV-S__x86_64
      }
    )
  end

  test "get_advisory_rhn_metadata baseline" do
    # Need to fix time because it's included in oval
    Time.stubs(:now => Time.utc(2014, 10, 10))
    with_baselines('xmlrpc', /\/get_advisory_rhn_metadata_(\d+).json$/) do |file, id|
      result = @service.get_advisory_rhn_metadata(id)
      canonicalize_json(result.to_json)
    end
  end

  test "get_advisory_cdn_metadata baseline" do
    with_baselines('xmlrpc', /\/get_advisory_cdn_metadata_(\d+).json$/) do |file, id|
      result = @service.get_advisory_cdn_metadata(id)
      canonicalize_json(result.to_json)
    end
  end

  test 'rhn cdn get_push_info' do
    with_current_user(releng_user) do
      e = @rhn_cdn_advisory
      assert e.can_push_rhn_live?
      refute e.can_push_cdn?
      assert e.can_push_cdn_if_live_push_succeeds?

      create_job_and_task = lambda do |job_class|
        job = job_class.create!(:errata => e, :pushed_by => User.current_user)
        job.pub_options['push_files'] = true
        job.create_pub_task(Push::PubClient.get_connection)
        e.reload
        job
      end

      (rhn_job,cdn_job) = [RhnLivePushJob,CdnPushJob].map(&create_job_and_task)

      # Because the test can potentially finish in 1 second, so add 1 minute to the
      # current time to prevent last job update time == last change state time (makes
      # push_job_since_last_push_ready method work)
      the_time = Time.now + 1.minute
      Time.stubs(:now).returns(the_time)

      rhn_info = @service.get_push_info(rhn_job.pub_task_id)
      cdn_info = @service.get_push_info(cdn_job.pub_task_id)

      assert_equal [], rhn_info['blockers']
      assert_equal true, rhn_info['can']
      assert_equal [], cdn_info['blockers']
      assert_equal true, cdn_info['can']

      # If the advisory state changes, pub should be able to detect it can no longer push
      e.change_state!(State::REL_PREP, User.current_user)
      rhn_info = @service.get_push_info(rhn_job.pub_task_id)
      cdn_info = @service.get_push_info(cdn_job.pub_task_id)

      assert_equal ['State REL_PREP invalid. Must be one of: PUSH_READY, IN_PUSH, SHIPPED_LIVE'], rhn_info['blockers']
      assert_equal false, rhn_info['can']
      assert_equal ['This errata cannot be pushed to RHN Live, thus may not be pushed to CDN'], cdn_info['blockers']
      assert_equal false, cdn_info['can']

      # change back, OK again
      e.change_state!(State::PUSH_READY, User.current_user)
      rhn_info = @service.get_push_info(rhn_job.pub_task_id)
      cdn_info = @service.get_push_info(cdn_job.pub_task_id)

      assert_equal [], rhn_info['blockers']
      assert_equal true, rhn_info['can']
      assert_equal [], cdn_info['blockers']
      assert_equal true, cdn_info['can']

      # CDN push not allowed to proceed if RHN push is known to have failed
      rhn_job.mark_as_failed!('phony failure')
      # Still in 'State::PUSH_READY' state because cdn push is active
      rhn_info = @service.get_push_info(rhn_job.pub_task_id)
      cdn_info = @service.get_push_info(cdn_job.pub_task_id)

      # pub can try the RHN push again, but can't try the CDN push until RHN is scheduled again
      assert_equal [], rhn_info['blockers']
      assert_equal true, rhn_info['can']
      assert_equal ['Advisory has not been shipped to rhn live channels yet.'], cdn_info['blockers']
      assert_equal false, cdn_info['can']

      # if we retry RHN push, CDN is also allowed to proceed
      rhn_job = create_job_and_task.call(RhnLivePushJob)
      rhn_info = @service.get_push_info(rhn_job.pub_task_id)
      cdn_info = @service.get_push_info(cdn_job.pub_task_id)

      assert_equal [], rhn_info['blockers']
      assert_equal true, rhn_info['can']
      assert_equal [], cdn_info['blockers']
      assert_equal true, cdn_info['can']
    end
  end

  test "ensure get_advisory_rhn_file_list returns correct rpms" do
    expected_results = { "libogg-1.1.4-3.el6_0.1" => {
      "sig_key" => "",
      "rpms" => {
        "libogg-debuginfo-1.1.4-3.el6_0.1.ppc64.rpm" =>
          [ "rhel-ppc64-server-6-debuginfo", "rhel-ppc64-server-optional-6-debuginfo" ],
        "libogg-1.1.4-3.el6_0.1.s390.rpm" =>
          [ "rhel-s390x-server-6" ],
       "libogg-devel-1.1.4-3.el6_0.1.ppc64.rpm" =>
          [ "rhel-ppc64-server-optional-6" ],
        "libogg-debuginfo-1.1.4-3.el6_0.1.s390.rpm" =>
          [ "rhel-s390x-server-6-debuginfo", "rhel-s390x-server-optional-6-debuginfo"],
        "libogg-devel-1.1.4-3.el6_0.1.ppc.rpm" =>
          [ "rhel-ppc64-server-optional-6" ],
        "libogg-debuginfo-1.1.4-3.el6_0.1.ppc.rpm" =>
          [ "rhel-ppc64-server-6-debuginfo", "rhel-ppc64-server-optional-6-debuginfo" ],
        "libogg-1.1.4-3.el6_0.1.x86_64.rpm" =>
           [ "rhel-x86_64-client-6", "rhel-x86_64-server-6",
             "rhel-x86_64-hpc-node-6", "rhel-x86_64-workstation-6" ],
        "libogg-devel-1.1.4-3.el6_0.1.s390x.rpm" =>
           [ "rhel-s390x-server-optional-6" ],
        "libogg-debuginfo-1.1.4-3.el6_0.1.s390x.rpm" =>
           [ "rhel-s390x-server-6-debuginfo",
             "rhel-s390x-server-optional-6-debuginfo" ],
        "libogg-devel-1.1.4-3.el6_0.1.s390.rpm" =>
           [ "rhel-s390x-server-optional-6" ],
        "libogg-1.1.4-3.el6_0.1.i686.rpm" =>
           [ "rhel-x86_64-client-6",   "rhel-i386-client-6",
             "rhel-x86_64-server-6",   "rhel-i386-server-6",
             "rhel-x86_64-hpc-node-6", "rhel-x86_64-workstation-6",
             "rhel-i386-workstation-6" ],
        "libogg-1.1.4-3.el6_0.1.src.rpm" =>
           [ "rhel-x86_64-hpc-node-optional-6",  "rhel-x86_64-client-6",
             "rhel-i386-client-6",               "rhel-x86_64-server-6",
             "rhel-i386-server-6",               "rhel-ppc64-server-6",
             "rhel-s390x-server-6",              "rhel-x86_64-server-optional-6",
             "rhel-i386-server-optional-6",      "rhel-ppc64-server-optional-6",
             "rhel-s390x-server-optional-6",     "rhel-x86_64-workstation-optional-6",
             "rhel-i386-workstation-optional-6", "rhel-x86_64-hpc-node-6",
             "rhel-x86_64-workstation-6",        "rhel-i386-workstation-6",
             "rhel-x86_64-client-optional-6",    "rhel-i386-client-optional-6" ],
        "libogg-1.1.4-3.el6_0.1.s390x.rpm" =>
          [ "rhel-s390x-server-6" ],
        "libogg-debuginfo-1.1.4-3.el6_0.1.i686.rpm" =>
          [ "rhel-x86_64-hpc-node-optional-6-debuginfo",  "rhel-x86_64-client-6-debuginfo",
            "rhel-i386-client-6-debuginfo",               "rhel-x86_64-server-6-debuginfo",
            "rhel-i386-server-6-debuginfo",               "rhel-x86_64-server-optional-6-debuginfo",
            "rhel-i386-server-optional-6-debuginfo",      "rhel-x86_64-workstation-optional-6-debuginfo",
            "rhel-i386-workstation-optional-6-debuginfo", "rhel-x86_64-hpc-node-6-debuginfo",
            "rhel-x86_64-workstation-6-debuginfo",        "rhel-i386-workstation-6-debuginfo",
            "rhel-x86_64-client-optional-6-debuginfo",    "rhel-i386-client-optional-6-debuginfo" ],
        "libogg-devel-docs-1.1.4-3.el6_0.1.noarch.rpm" =>
           [ "rhel-x86_64-hpc-node-optional-6",  "rhel-x86_64-server-optional-6",
             "rhel-i386-server-optional-6",      "rhel-ppc64-server-optional-6",
             "rhel-s390x-server-optional-6",     "rhel-x86_64-workstation-optional-6",
             "rhel-i386-workstation-optional-6", "rhel-x86_64-client-optional-6",
             "rhel-i386-client-optional-6" ],
        "libogg-1.1.4-3.el6_0.1.ppc.rpm" =>
          [ "rhel-ppc64-server-6" ],
        "libogg-1.1.4-3.el6_0.1.ppc64.rpm" =>
          [ "rhel-ppc64-server-6" ],
        "libogg-devel-1.1.4-3.el6_0.1.x86_64.rpm" =>
          [ "rhel-x86_64-hpc-node-optional-6",    "rhel-x86_64-server-optional-6",
            "rhel-x86_64-workstation-optional-6", "rhel-x86_64-client-optional-6" ],
        "libogg-devel-1.1.4-3.el6_0.1.i686.rpm" =>
          [ "rhel-x86_64-hpc-node-optional-6",  "rhel-x86_64-server-optional-6",
            "rhel-i386-server-optional-6",      "rhel-x86_64-workstation-optional-6",
            "rhel-i386-workstation-optional-6", "rhel-x86_64-client-optional-6",
            "rhel-i386-client-optional-6" ],
        "libogg-debuginfo-1.1.4-3.el6_0.1.x86_64.rpm" =>
          [ "rhel-x86_64-hpc-node-optional-6-debuginfo",    "rhel-x86_64-client-6-debuginfo",
            "rhel-x86_64-server-6-debuginfo",               "rhel-x86_64-server-optional-6-debuginfo",
            "rhel-x86_64-workstation-optional-6-debuginfo", "rhel-x86_64-hpc-node-6-debuginfo",
            "rhel-x86_64-workstation-6-debuginfo",          "rhel-x86_64-client-optional-6-debuginfo" ] },}}

    actual_results = @service.get_advisory_rhn_file_list(rhba_async.id)
    assert_file_list_equal(expected_results, actual_results)
  end

  test "ensure get_advisory_cdn_file_list returns correct rpms" do
    expected_results = { "libogg-1.1.4-3.el6_0.1"=> {
      "sig_key" => "",
      "rpms" =>
        { "libogg-1.1.4-3.el6_0.1.x86_64.rpm" =>
            [ "rhel-6-server-rpms__6Server__x86_64", "rhel-6-client-rpms__6Client__x86_64" ],
          "libogg-devel-1.1.4-3.el6_0.1.s390x.rpm" =>
            [ "rhel-6-server-optional-rpms__6Server__x390x" ],
          "libogg-devel-1.1.4-3.el6_0.1.i686.rpm" =>
            [ "rhel-6-server-optional-rpms__6Server__x86_64", "rhel-6-server-optional-rpms__6Server__i386" ],
          "libogg-devel-docs-1.1.4-3.el6_0.1.noarch.rpm" =>
            [ "rhel-6-server-optional-rpms__6Server__x86_64", "rhel-6-server-optional-rpms__6Server__i386",
              "rhel-6-server-optional-rpms__6Server__ppc64",  "rhel-6-server-optional-rpms__6Server__x390x" ],
          "libogg-debuginfo-1.1.4-3.el6_0.1.i686.rpm"=>
            [ "rhel-6-server-debuginfo-rpms__6Server__x86_64", "rhel-6-server-debuginfo-rpms__6Server__i386",
              "rhel-6-client-debuginfo-rpms__6Client__x86_64" ],
          "libogg-devel-1.1.4-3.el6_0.1.ppc64.rpm"=>
            [ "rhel-6-server-optional-rpms__6Server__ppc64" ],
          "libogg-debuginfo-1.1.4-3.el6_0.1.s390x.rpm" =>
            [ "rhel-6-server-debuginfo-rpms__6Server__s390x" ],
          "libogg-1.1.4-3.el6_0.1.s390x.rpm" =>
            [ "rhel-6-server-rpms__6Server__s390x" ],
          "libogg-devel-1.1.4-3.el6_0.1.s390.rpm" =>
            [ "rhel-6-server-optional-rpms__6Server__x390x" ],
          "libogg-devel-1.1.4-3.el6_0.1.x86_64.rpm" =>
            [ "rhel-6-server-optional-rpms__6Server__x86_64" ],
          "libogg-debuginfo-1.1.4-3.el6_0.1.s390.rpm" =>
            [ "rhel-6-server-debuginfo-rpms__6Server__s390x" ],
          "libogg-debuginfo-1.1.4-3.el6_0.1.ppc64.rpm" =>
            [ "rhel-6-server-debuginfo-rpms__6Server__ppc64" ],
          "libogg-1.1.4-3.el6_0.1.src.rpm" =>
            ["rhel-6-server-source-rpms__6Server__x86_64", "rhel-6-client-source-rpms__6Client__x86_64" ],
          "libogg-1.1.4-3.el6_0.1.s390.rpm" =>
            [ "rhel-6-server-rpms__6Server__s390x" ],
          "libogg-1.1.4-3.el6_0.1.i686.rpm" =>
            [ "rhel-6-server-rpms__6Server__x86_64", "rhel-6-server-rpms__6Server__i386",
              "rhel-6-client-rpms__6Client__x86_64", "rhel-6-client-rpms__6Client__i386" ],
          "libogg-devel-1.1.4-3.el6_0.1.ppc.rpm" =>
            [ "rhel-6-server-optional-rpms__6Server__ppc64" ],
          "libogg-debuginfo-1.1.4-3.el6_0.1.x86_64.rpm" =>
            [ "rhel-6-server-debuginfo-rpms__6Server__x86_64", "rhel-6-client-debuginfo-rpms__6Client__x86_64" ],
          "libogg-debuginfo-1.1.4-3.el6_0.1.ppc.rpm" =>
            [ "rhel-6-server-debuginfo-rpms__6Server__ppc64" ],
          "libogg-1.1.4-3.el6_0.1.ppc.rpm" =>
            [ "rhel-6-server-rpms__6Server__ppc64" ],
          "libogg-1.1.4-3.el6_0.1.ppc64.rpm"=>
            [ "rhel-6-server-rpms__6Server__ppc64" ] },}}

    actual_results = @service.get_advisory_cdn_file_list(rhba_async.id)
    assert_file_list_equal(expected_results, actual_results)
  end

  test "ensure get_advisory_cdn_file_list returns correct rpms for shadow push" do
    expected_results = { "libogg-1.1.4-3.el6_0.1"=> {
      "sig_key" => "",
      "rpms" =>
        { "libogg-1.1.4-3.el6_0.1.x86_64.rpm" =>
            [ "shadow-rhel-6-server-rpms__6Server__x86_64", "shadow-rhel-6-client-rpms__6Client__x86_64" ],
          "libogg-devel-1.1.4-3.el6_0.1.s390x.rpm" =>
            [ "shadow-rhel-6-server-optional-rpms__6Server__x390x" ],
          "libogg-devel-1.1.4-3.el6_0.1.i686.rpm" =>
            [ "shadow-rhel-6-server-optional-rpms__6Server__x86_64", "shadow-rhel-6-server-optional-rpms__6Server__i386" ],
          "libogg-devel-docs-1.1.4-3.el6_0.1.noarch.rpm" =>
            [ "shadow-rhel-6-server-optional-rpms__6Server__x86_64", "shadow-rhel-6-server-optional-rpms__6Server__i386",
              "shadow-rhel-6-server-optional-rpms__6Server__ppc64",  "shadow-rhel-6-server-optional-rpms__6Server__x390x" ],
          "libogg-debuginfo-1.1.4-3.el6_0.1.i686.rpm"=>
            [ "shadow-rhel-6-server-debuginfo-rpms__6Server__x86_64", "shadow-rhel-6-server-debuginfo-rpms__6Server__i386",
              "shadow-rhel-6-client-debuginfo-rpms__6Client__x86_64" ],
          "libogg-devel-1.1.4-3.el6_0.1.ppc64.rpm"=>
            [ "shadow-rhel-6-server-optional-rpms__6Server__ppc64" ],
          "libogg-debuginfo-1.1.4-3.el6_0.1.s390x.rpm" =>
            [ "shadow-rhel-6-server-debuginfo-rpms__6Server__s390x" ],
          "libogg-1.1.4-3.el6_0.1.s390x.rpm" =>
            [ "shadow-rhel-6-server-rpms__6Server__s390x" ],
          "libogg-devel-1.1.4-3.el6_0.1.s390.rpm" =>
            [ "shadow-rhel-6-server-optional-rpms__6Server__x390x" ],
          "libogg-devel-1.1.4-3.el6_0.1.x86_64.rpm" =>
            [ "shadow-rhel-6-server-optional-rpms__6Server__x86_64" ],
          "libogg-debuginfo-1.1.4-3.el6_0.1.s390.rpm" =>
            [ "shadow-rhel-6-server-debuginfo-rpms__6Server__s390x" ],
          "libogg-debuginfo-1.1.4-3.el6_0.1.ppc64.rpm" =>
            [ "shadow-rhel-6-server-debuginfo-rpms__6Server__ppc64" ],
          "libogg-1.1.4-3.el6_0.1.src.rpm" =>
            ["shadow-rhel-6-server-source-rpms__6Server__x86_64", "shadow-rhel-6-client-source-rpms__6Client__x86_64" ],
          "libogg-1.1.4-3.el6_0.1.s390.rpm" =>
            [ "shadow-rhel-6-server-rpms__6Server__s390x" ],
          "libogg-1.1.4-3.el6_0.1.i686.rpm" =>
            [ "shadow-rhel-6-server-rpms__6Server__x86_64", "shadow-rhel-6-server-rpms__6Server__i386",
              "shadow-rhel-6-client-rpms__6Client__x86_64", "shadow-rhel-6-client-rpms__6Client__i386" ],
          "libogg-devel-1.1.4-3.el6_0.1.ppc.rpm" =>
            [ "shadow-rhel-6-server-optional-rpms__6Server__ppc64" ],
          "libogg-debuginfo-1.1.4-3.el6_0.1.x86_64.rpm" =>
            [ "shadow-rhel-6-server-debuginfo-rpms__6Server__x86_64", "shadow-rhel-6-client-debuginfo-rpms__6Client__x86_64" ],
          "libogg-debuginfo-1.1.4-3.el6_0.1.ppc.rpm" =>
            [ "shadow-rhel-6-server-debuginfo-rpms__6Server__ppc64" ],
          "libogg-1.1.4-3.el6_0.1.ppc.rpm" =>
            [ "shadow-rhel-6-server-rpms__6Server__ppc64" ],
          "libogg-1.1.4-3.el6_0.1.ppc64.rpm"=>
            [ "shadow-rhel-6-server-rpms__6Server__ppc64" ] },}}

    actual_results = @service.get_advisory_cdn_file_list(rhba_async.id, true)
    assert_file_list_equal(expected_results, actual_results)
  end

  test "ensure get_advisory_rhn_file_list follows the package restriction rule" do
    variants = %w[6Server 6Client]
    targets  = %w[cdn]
    expected_channels = [
      "rhel-i386-client-6",   "rhel-i386-client-6-debuginfo",
      "rhel-x86_64-client-6", "rhel-x86_64-client-6-debuginfo",
      "rhel-i386-server-6",   "rhel-i386-server-6-debuginfo",
      "rhel-ppc64-server-6",  "rhel-ppc64-server-6-debuginfo",
      "rhel-s390x-server-6",  "rhel-s390x-server-6-debuginfo",
      "rhel-x86_64-server-6", "rhel-x86_64-server-6-debuginfo" ]

    test_file_list(:rhn, variants, targets, expected_channels)
  end

  test "ensure get_advisory_cdn_file_list follows the package restriction rule" do
    variants = %w[6Server 6Client]
    targets  = %w[rhn_live, rhn_stage]
    expected_repos = [
      "rhel-6-client-debuginfo-rpms__6Client__x86_64", "rhel-6-client-rpms__6Client__i386",
      "rhel-6-client-rpms__6Client__x86_64",           "rhel-6-client-source-rpms__6Client__x86_64",
      "rhel-6-server-debuginfo-rpms__6Server__i386",   "rhel-6-server-debuginfo-rpms__6Server__ppc64",
      "rhel-6-server-debuginfo-rpms__6Server__s390x",  "rhel-6-server-debuginfo-rpms__6Server__x86_64",
      "rhel-6-server-rpms__6Server__i386",             "rhel-6-server-rpms__6Server__ppc64",
      "rhel-6-server-rpms__6Server__s390x",            "rhel-6-server-rpms__6Server__x86_64",
      "rhel-6-server-source-rpms__6Server__x86_64" ]

    test_file_list(:cdn, variants, targets, expected_repos)
  end

  def test_file_list(type, variants, targets, expected_channel_or_repos)
    file_list_method = "get_advisory_#{type}_file_list"
    # before restricting 6Server and 6Client to the push targets
    # the file list should includes the expected channels
    before = @service.send(file_list_method, rhba_async.id)
    assert_channels_or_repos_exist(before, expected_channel_or_repos)

    # restrict 6Server and 6Client to the push targets
    restrict_errata_push_targets_by_variants(rhba_async, variants , targets)

    # after restricting 6Server and 6Client to the push targets
    # the file list should excludes the expected channels
    after = @service.send(file_list_method, rhba_async.id)
    assert_channels_or_repos_not_exist(after, expected_channel_or_repos)
  end

  def assert_file_list_equal(expected_results, actual_results)
    assert_array_equal expected_results.keys, actual_results.keys
    expected_results.each_pair do |nvr, list|
      expected_list = list['rpms']
      actual_list   = actual_results[nvr]['rpms']
      assert_array_equal expected_list.keys, actual_list.keys
      assert_array_equal expected_list.values.flatten, actual_list.values.flatten
    end
  end

  def assert_channels_or_repos_not_exist(actual_results, expected_channels_or_repos)
    assert_channels_or_repos_exist(actual_results, expected_channels_or_repos, true)
  end

  def assert_channels_or_repos_exist(actual_results, expected_channels_or_repos, invert = false)
    method = (invert) ? "refute" : "assert"
    actual_results.values.each do |list|
      actual_channels_or_repos = list['rpms'].values.flatten
      # check whether all expected channels/repos are in the actual channel/repo list or not
      missing = expected_channels_or_repos - actual_channels_or_repos
      self.send(method, missing.empty?)
      # make sure the missing channels/repos match the expected channel/repos if invert
      assert_array_equal expected_channels_or_repos, missing if invert
    end
  end

  def restrict_errata_push_targets_by_variants(errata, variants, targets)
    restricted_variants = Hash.new{ |hash,key| hash[key] = [] }
    targets = PushTarget.where(:name => targets)
    errata.build_mappings.each do |m|
      m.build_product_listing_iterator do |rpm, variant, brew_build, arch_list|
        next if !variants.include?(variant.name)
        if restriction = PackageRestriction.find_by_package_id_and_variant_id(brew_build.package, variant)
          restriction.update_attributes!(:push_targets => targets)
        else
          PackageRestriction.create!(:package => brew_build.package, :variant => variant, :push_targets => targets)
        end
      end
    end
  end

  test 'get_ftp_paths ignores non-rpm files' do
    e = Errata.find(16397)

    # this advisory should be only non-RPM content
    types = e.build_mappings.pluck('distinct brew_archive_type_id')
    assert types.any?
    refute types.include?(nil)

    result = @service.get_ftp_paths(e.id)
    assert_equal({}, result)
  end

  test 'can get push details for altsrc push' do
    job = AltsrcPushJob.find(11403)
    result = @service.get_push_info(job.pub_task_id)
    assert_equal 'altsrctest', result['target']
    assert_equal [], result['blockers']
    assert result['can']
  end

  test 'get_push_info conveys blockers correctly for altsrc push' do
    RHBA.any_instance.stubs(:push_altsrc_blockers => ['simulated', 'push blockers'])
    job = AltsrcPushJob.find(11403)
    result = @service.get_push_info(job.pub_task_id)
    assert_equal 'altsrctest', result['target']
    assert_equal ['simulated', 'push blockers'], result['blockers']
    refute result['can']
  end

  test 'get_push_info searches by advisory argument' do
    job = PushJob.find(47310)
    assert_equal 61905, job.pub_task_id
    assert_equal 20044, job.errata_id
    assert_equal 'RHBA-2015:1395-06', job.errata.fulladvisory

    # Can find it by task ID alone
    result = @service.get_push_info(61905)
    assert result['can'], result.inspect

    # Can find it also by errata ID or name
    assert_equal result, @service.get_push_info(61905, 20044)
    assert_equal result, @service.get_push_info(61905, '20044')
    assert_equal result, @service.get_push_info(61905, 'RHBA-2015:1395-06')
    assert_equal result, @service.get_push_info(61905, 'RHBA-2015:1395')

    # Raises if bad advisory given
    error = assert_raises(ArgumentError) do
      @service.get_push_info(61905, 8888888)
    end
    assert_equal "Can't find errata '8888888'", error.message

    # Raises if correct advisory provided but does not match this pub task
    error = assert_raises(ArgumentError) do
      @service.get_push_info(61905, 2128)
    end
    assert_equal 'Cannot find a push job with pub task 61905, advisory 2128', error.message
  end

  test 'get_push_info raises if ambiguous' do
    # If get_push_info matches several jobs, then complain.
    # NOTE: cannot actually make this happen with current schema, so we mock.
    # Test can be updated after bug 1300153 to use fixtures.
    PushJob.stubs(:where => PushJob.unscoped)

    error = assert_raises(ArgumentError) do
      @service.get_push_info(12345)
    end
    assert_equal 'Multiple push jobs matching pub task 12345', error.message
  end

  test 'getErrataBrewBuilds output as expected' do
    [11145, 16409].each do |id|
      name = Errata.find(id).advisory_name
      response = @service.getErrataBrewBuilds(name)
      assert_testdata_equal "xmlrpc/getErrataBrewBuilds-#{id}.json", canonicalize_json(response.to_json)
    end
  end

  test 'get_advisory_cdn_docker_file_list baseline test' do
    with_baselines('xmlrpc', /get_advisory_cdn_docker_file_list_(\d+)\.json/) do |file,id|
      canonicalize_json @service.get_advisory_cdn_docker_file_list(id).to_json
    end
  end

  test 'docker advisory file list repos test' do
    advisory = Errata.find(21100)
    nvr = 'rhel-server-docker-7.1-3'
    image = 'rhel-server-docker-7.1-3.x86_64.tar.gz'

    assert_array_equal [nvr], advisory.brew_builds.pluck(:nvr)
    assert_array_equal [image], advisory.brew_files.pluck(:name)

    # returns repos from get_advisory_cdn_nonrpm_file_list
    nonrpm_repos = lambda do
      file_list = @service.get_advisory_cdn_nonrpm_file_list(advisory.id)
      file_list[nvr]['archives']["images/#{image}"]['repos']
    end

    # returns repos from get_advisory_cdn_docker_file_list
    docker_repos = lambda do
      file_list = @service.get_advisory_cdn_docker_file_list(advisory.id)
      file_list[nvr]['docker'][image]['repos'].keys
    end

    expected_repos = ["test_docker_7-1"]
    assert_array_equal expected_repos, nonrpm_repos.call
    assert_array_equal expected_repos, docker_repos.call

    # Create a new package mapping to another repo
    CdnRepoPackage.create!(:cdn_repo_id => 9999007, :package_id => 22001)

    expected_repos = ["test_2_docker_7-1", "test_docker_7-1"]
    assert_array_equal expected_repos, nonrpm_repos.call
    assert_array_equal expected_repos, docker_repos.call
  end

  test 'docker tags are unique' do
    advisory = Errata.find(21100)
    nvr = 'rhel-server-docker-7.1-3'
    image = 'rhel-server-docker-7.1-3.x86_64.tar.gz'
    repo = CdnRepo.find_by_name('test_docker_7-1')
    build = BrewBuild.find_by_nvr(nvr)

    # returns tags from get_advisory_cdn_docker_file_list
    docker_tags = lambda do
      file_list = @service.get_advisory_cdn_docker_file_list(advisory.id)
      file_list[nvr]['docker'][image]['repos'][repo.name]['tags']
    end

    # existing tags
    assert_array_equal ['latest', 'test-7.1.z', '3-7.1'], docker_tags.call

    mapping = repo.cdn_repo_packages.where(:package_id => build.package_id).first

    # create some more tag templates
    ['{{release}}-{{version(2)}}', 'test_tag'].each do |tag_template|
      mapping.cdn_repo_package_tags <<
        CdnRepoPackageTag.new(:cdn_repo_package_id => mapping, :tag_template => tag_template)
    end

    # should now be 6 tag templates
    assert_equal 6, mapping.cdn_repo_package_tags.length

    # but only 4 unique resulting tags for this variant
    assert_array_equal ['latest', 'test-7.1.z', '3-7.1', 'test_tag'], docker_tags.call
  end

  #
  # (These could easily be included in with the non-PDC baselines, but let's
  # keep them separate for now. It means we can see PDC related baseline
  # failures more easily and also run just these tests while debugging.)
  #
  test 'get_advisory_rhn_file_list baseline test for pdc' do
    VCR.use_cassettes_for(:pdc_ceph21) do
      with_baselines('xmlrpc', /get_pdc_advisory_rhn_file_list_(\d+)\.json/) do |file,id|
        canonicalize_json @service.get_advisory_rhn_file_list(id).to_json
      end
    end
  end

  test 'get_advisory_cdn_file_list baseline test for pdc' do
    VCR.use_cassettes_for(:pdc_ceph21) do
      with_baselines('xmlrpc', /get_pdc_advisory_cdn_file_list_(\d+)\.json/) do |file,id|
        canonicalize_json @service.get_advisory_cdn_file_list(id).to_json
      end
    end
  end

  test "get_advisory_rhn_metadata baseline for pdc" do
    VCR.use_cassettes_for(:pdc_ceph21) do
      with_baselines('xmlrpc', /\/get_pdc_advisory_rhn_metadata_(\d+).json$/) do |file, id|
        canonicalize_json @service.get_advisory_rhn_metadata(id).to_json
      end
    end
  end

  test "get_advisory_cdn_metadata baseline for pdc" do
    VCR.use_cassettes_for(:pdc_ceph21) do
      with_baselines('xmlrpc', /\/get_pdc_advisory_cdn_metadata_(\d+).json$/) do |file, id|
        canonicalize_json @service.get_advisory_cdn_metadata(id).to_json
      end
    end
  end

end
