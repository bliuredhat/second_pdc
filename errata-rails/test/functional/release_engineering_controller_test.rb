require 'test_helper'

class ReleaseEngineeringControllerTest < ActionController::TestCase
  setup do
    auth_as releng_user

    @b = BrewBuild.first
    @pv = ProductVersion.find_active.first

    @pr = PdcRelease.find_by_pdc_id('ceph-2.1-updates@rhel-7')
    @brew_build = BrewBuild.find_by_nvr('python-crypto-2.6.1-1.2.el7cp')

    @rhel6 = ProductVersion.find_by_name!('RHEL-6')
    @rhel6_build = @rhel6.released_brew_builds.first
  end

  [:html, :json].each do |format|
    test "add released package #{format}" do
      initial_rp = ReleasedPackage.pluck('distinct id')
      created_rp = lambda{ ReleasedPackage.where('id not in (?)', initial_rp) }

      get_error = lambda do
        format == :html ? response.body : JSON.parse(response.body)['error']
      end

      nvrs = ["sblim-cim-client2-2.1.3-2.el6",
              "tomcat6-6.0.24-33.el6",
              "btrfs-progs-0.19-12.el6",
              "kdenetwork-4.3.4-11.el6_0.1"]
      product_version = ProductVersion.find_by_name "RHEL-6"

      assert_difference("JobTracker.count", 1) do
        post :add_released_package,
          :input => {
            :product_version => product_version.id,
            :nvrs => nvrs.join("\n"),
            :reason => 'testing'
          },
          :format => format
      end

      self.send("assert_add_released_packages_#{format}", nvrs.size)

      # Run the scheduled delayed jobs to add the released packages
      run_add_released_packages_job(Delayed::Job.last(nvrs.size))

      older_nvrs = ['tomcat6-6.0.24-30.el6', 'sblim-cim-client2-2.1.3-1.el6']
      # Try to add 2 older builds. The request should fail because the existing
      # released packages are newer.
      assert_no_difference("JobTracker.count") do
        post :add_released_package,
          :input => {
            :product_version => product_version.id,
            :nvrs => older_nvrs,
            :reason => 'testing'
          },
          :format => format
      end

      # html - Return status :success and go to the 2nd page to ask for user confirmation.
      # json - Fail and return status :unprocessable_entity
      status = format == :html ? :success : :unprocessable_entity
      assert_response status

      [ "Brew build 'sblim-cim-client2-2.1.3-1.el6' is older than the latest released brew build 'sblim-cim-client2-2.1.3-2.el6'.",
        "Brew build 'tomcat6-6.0.24-30.el6' is older than the latest released brew build 'tomcat6-6.0.24-33.el6'."
      ].each do |expected_message|
        # Escape html to match the response data for html request
        expected_message = format == :html ? ERB::Util.h(expected_message) : expected_message
        assert_match expected_message, get_error.call
      end

      # Try to add the 2 older builds again with :skip_brew_build_version_check
      # option. The request should pass this time.
      assert_difference("JobTracker.count", 1) do
        assert_difference("ReleasedPackageUpdate.count", 1) do
          post :add_released_package,
            :input => {
              :product_version => product_version.id,
              :nvrs => older_nvrs,
              :reason => 'test_reason'
            },
            :skip_brew_build_version_check => format == :html ? '1' : true,
            :format => format
        end
        assert_equal releng_user.id, ReleasedPackageUpdate.last.who_id
        assert_equal 'test_reason', ReleasedPackageUpdate.last.reason
      end

      # every released package we've created should have an associated update.
      created_rp.call.each do |rp|
        assert rp.released_package_update, "Update missing for released package #{rp.full_path}"
      end

      self.send("assert_add_released_packages_#{format}", older_nvrs.size)
    end

  end

  def run_add_released_packages_job(jobs)
    # Hack the original method and force it to use cache
    real_method = ReleasedPackage.method(:make_released_packages_for_build)
    ActiveSupport::TestCase.with_replaced_method(ReleasedPackage, :make_released_packages_for_build,
      lambda{ |*args|
        args[-1].merge!(:use_product_listing_cache => true)
        real_method.call(*args)
      }) do
        jobs.map(&:invoke_job)
    end
  end

  def assert_add_released_packages_json(expected_job_count)
    assert_response :success
    resp = JSON.parse(response.body)
    tracker = JobTracker.last
    assert_equal tracker.id, resp['id']
    assert_equal 'RHEL-6 Released Package Load', resp['name']
    assert_equal "Adding/updating #{expected_job_count} released packages", resp['description']
    assert_equal expected_job_count, resp['jobs'].length
    resp['jobs'].each do |j|
      assert_equal 'QUEUED', j['status']
      assert_match 'ReleasedPackage.make_released_packages_for_build', j['task']
    end
  end

  def assert_add_released_packages_html(expected_job_count)
    assert_response :redirect
    assert_redirected_to :controller => :job_trackers, :action => :show, :id => JobTracker.last.id
  end

  test 'add released package complains if no builds provided' do
    [
      ['html', :unprocessable_entity, lambda{ flash[:error] }],
      ['json', :unprocessable_entity, lambda{ JSON.parse(response.body)['error'] }]
    ].each do |format,response_code,get_error|
      assert_no_difference('JobTracker.count') do
        post :add_released_package,
          :input => {:product_version => ProductVersion.first.id },
          :format => format
      end
      assert_response response_code
      assert_match 'Please provide one or more brew builds', get_error.call
    end
  end

  test 'add released package complains if reason is blank' do
    [
      ['html', :unprocessable_entity, lambda{ flash[:error] }],
      ['json', :unprocessable_entity, lambda{ JSON.parse(response.body)['error'] }]
    ].each do |format,response_code,get_error|
      assert_no_difference('JobTracker.count') do
        post :add_released_package,
          :input => {
            :product_version => ProductVersion.first.id,
            :nvrs => 'foobar',
          },
          :format => format
      end
      assert_response response_code
      assert_match 'Please provide a reason', get_error.call
    end
  end

  test 'released packages' do
    get :released_packages, :id => @rhel6.id
    assert_select 'h1', "Released Brew Builds for #{@rhel6.name}"
    assert_select 'td a', @rhel6_build.nvr
  end

  test 'remove released packages' do
    get :remove_released_package, :id => @rhel6.id
    assert_select '.eso-tab-bar a.selected', :count => 1, :text => 'Browse Released Packages'
    assert_select 'h1', "Remove Released Brew Builds for #{@rhel6.name}"
    assert_select 'td a', @rhel6_build.nvr
    assert_select "td input[type=checkbox][name='released_builds_to_remove[]'][value=#{@rhel6_build.id}]"
  end

  test 'remove released packages submit' do
    assert @rhel6.released_brew_builds.include?(@rhel6_build)
    assert_difference('@rhel6.reload.released_brew_builds.count', -1) do
      post :remove_released_package, :id => @rhel6.id, :released_builds_to_remove => [@rhel6_build.id]
      assert_redirected_to :action => :released_packages, :id => @rhel6.id
      assert_equal '1 package removed.', flash[:notice]
    end
    refute @rhel6.released_brew_builds.include?(@rhel6_build)
  end

  def mock_get_product_listings_response(response)
    ProductListing.expects(:find_or_fetch).once.with(){|pv,b,opts|
      pv == @pv && b == @b
    }.tap{|e|
      if response.kind_of?(Exception)
        e.raises(response)
      else
        e.returns(response)
      end
    }
  end

  def mock_get_pdc_product_listings_response(response)
    PdcProductListing.expects(:find_or_fetch).once.with(){|pr,b,opts|
      pr == @pr && b == @brew_build
    }.tap{|e|
      if response.kind_of?(Exception)
        e.raises(response)
      else
        e.returns(response)
      end
    }
  end

  test 'product listings get' do
    get :product_listings
    assert_response :success
  end

  def assert_expected_assigns(response, statement=nil)
    assert_response :success
    assert_select "option[value=#{@pv.id}][selected=selected]"
    assert_select "input[id=rp_nvr][value=#{@b.nvr}]"
    assert_equal @pv, assigns[:product_version]
    assert_equal @b, assigns[:brew_build]
    assert_equal response, assigns[:listing]
    assert assigns[:statements].include?(statement) if statement
  end

  def product_listings_test(http_method, mock_listing)
    mock_get_product_listings_response(mock_listing)
    method(http_method).call :product_listings, :rp => { :pv_or_pr_id => @pv.id, :nvr => @b.nvr }
    assert_expected_assigns(mock_listing)

    # sanity check of the product listing table which should be
    # rendered.  It should show the variant, file and arch.
    assert_match %r{<td>Some-Variant</td>.*autotrace.*<td>x86_64</td></tr>}m, response.body
  end

  test 'product listings' do
    mock_listing = [
      Struct.
        new('MockListing', :variant_label, :brew_file, :destination_arch).
        new('Some-Variant', @b.brew_files.first, Arch.find_by_name!('x86_64'))
    ]
    product_listings_test(:get, mock_listing)
    product_listings_test(:post, mock_listing)
  end

  test 'product listings empty' do
    mock_get_product_listings_response([])
    post :product_listings, :rp => { :pv_or_pr_id => @pv.id, :nvr => @b.nvr }
    assert_expected_assigns([], "No product listing data found!")
  end

  test 'product listings brew error' do
    mock_get_product_listings_response(
      XMLRPC::FaultException.new(123, "simulated fault"))
    post :product_listings, :rp => { :pv_or_pr_id => @pv.id, :nvr => @b.nvr }
    assert_expected_assigns(nil)
    assert_match %r{\b123: simulated fault\b}, response.body
  end

  test 'product listings cache matches brew' do
    cache = ProductListingCache.first
    mock_listing = cache.get_listing

    ProductListing.expects(:find_or_fetch).once.with(){|pv,b,opts|
      pv == cache.product_version && b == cache.brew_build
    }.returns(mock_listing)

    post :product_listings, :rp => { :pv_or_pr_id => cache.product_version_id, :nvr => cache.brew_build.nvr }

    assert_response :success
    assert_match %r{<td>ES</td>.*qpidd.*<td>x86_64</td></tr>}m, response.body
    assert_no_match %r{Cached listing does not match that from Brew}, response.body
  end

  test 'product listings cache mismatch' do
    cache = ProductListingCache.first
    mock_listing = cache.get_listing
    mock_listing.pop

    ProductListing.expects(:find_or_fetch).once.with(){|pv,b,opts|
      pv == cache.product_version && b == cache.brew_build
    }.returns(mock_listing)

    post :product_listings, :rp => { :pv_or_pr_id => cache.product_version_id, :nvr => cache.brew_build.nvr }

    assert_response :success
    assert_match %r{Cached listing does not match that from Brew}, response.body
  end

  test 'show released build for docker' do
    e = Errata.find(21100)
    assert e.has_docker?

    # "Release" the advisory
    e.change_state!(State::IN_PUSH, admin_user)
    e.change_state!(State::SHIPPED_LIVE, admin_user)

    # This should not respond with :internal_server_error (bug 1354399)
    get :show_released_build, :id => e.brew_builds.first
    assert_response :success
  end

  test 'pdc product listings' do
    VCR.insert_cassette 'pdc_producting_listing'

    post :pdc_product_listings, :rp => { :pv_or_pr_id => @pr.id, :nvr => @brew_build.nvr }
    assert_response :success
    assert_match %r{<td>MON</td>.*src/python-crypto-2.6.1-1.2.el7cp.src.rpm.*<td>x86_64</td></tr>}m, response.body
    assert_match %r{<td>MON</td>.*x86_64/python-crypto-debuginfo-2.6.1-1.2.el7cp.x86_64.rpm.*<td>x86_64</td></tr>}m,
                 response.body
    assert_no_match %r{Cached listing does not match that from Brew}, response.body

    VCR.eject_cassette
  end

  test 'pdc product listings brew error' do
    PdcRelease.expects(:active_releases).returns(Array.wrap(@pr))
    mock_get_pdc_product_listings_response(
      XMLRPC::FaultException.new(123, "simulated fault"))
    post :pdc_product_listings, :rp => { :pv_or_pr_id => @pr.id, :nvr => @brew_build.nvr }
    assert_match %r{\b123: simulated fault\b}, response.body
  end

  test 'pdc product listings cache mismatch' do
    VCR.insert_cassette 'modified_inconsistent_pdc_producting_listing'

    post :pdc_product_listings, :rp => { :pv_or_pr_id => @pr.id, :nvr => @brew_build.nvr }
    assert_response :success
    assert_match %r{Cached listing does not match that from Brew}, response.body

    VCR.eject_cassette
  end
end
