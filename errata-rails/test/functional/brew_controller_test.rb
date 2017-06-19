require 'test_helper'

class BrewControllerTest < ActionController::TestCase

  def setup
    # Found this mapping since, it's release is connected to a
    # QuarterlyUpdate which has brew tags set
    @mapping = ErrataBrewMapping.find(21198)
    @brew_build, @errata = @mapping.brew_build, @mapping.errata

    @errata_rpm_and_nonrpm = RHBA.find(16396)
    @errata_nonrpm_only = RHBA.find(16397)

    @rpm_and_nonrpm_mapping = ErrataBrewMapping.find(55968)

    # Be a devel user
    auth_as devel_user
  end

  test 'testdata preconditions' do
    @errata_rpm_and_nonrpm.tap do |e|
      rpm_count = e.build_mappings.for_rpms.count
      nonrpm_count = e.build_mappings.for_nonrpms.count

      assert rpm_count > 0,    'fixture problem: need at least 1 rpm'
      assert nonrpm_count > 0, 'fixture problem: need at least 1 non-rpm'
      assert rpm_count != nonrpm_count, 'fixture problem: need different rpm and non-rpm counts'
    end

    @errata_nonrpm_only.tap do |e|
      rpm_count = e.build_mappings.for_rpms.count
      nonrpm_count = e.build_mappings.for_nonrpms.count

      assert rpm_count == 0,   'fixture problem: need 0 rpms'
      assert nonrpm_count > 0, 'fixture problem: need at least 1 non-rpm'
    end
  end

  test "removing a build" do
    # Remember initial build count (and do sanity check)
    old_build_count = @errata.brew_builds.count
    assert @errata.brew_builds.include?(@brew_build)

    # Remove the build
    post :remove_build, :id=>@mapping

    # Did it work?
    assert_response :redirect
    assert_redirected_to :controller=>:brew, :action=>:list_files, :id=>@errata

    # Is the build really removed?
    assert_equal old_build_count - 1, @errata.brew_builds.count
    refute @errata.brew_builds.include?(@brew_build)

  end

  #
  # Tests the simplest case, that BrewBuild returns a build via rpc. No
  # need to test the actual rpc call here. That should happen in a
  # BrewBuild unit test.
  #
  test "find build by rpc" do
    name = 'foo'
    BrewBuild.expects(:make_from_rpc_without_mandatory_srpm).with(name).returns(BrewBuild.last)

    assert_equal BrewBuild.last, @controller.send(:find_build_by_rpc, name)
  end

  test "test build by rpc raises error" do
    BrewBuild.expects(:make_from_rpc_without_mandatory_srpm).raises(Exception, 'Currently trapped in a non-linear time continuum!')
    assert_raise Exception do
      assert_nil @controller.send(:find_build_by_rpc, 'libbeer.rpm')
      assert @controller.assigns.has_key? :build_search_errors
      assert_match %r{Error retrieving}, @controller.assigns[:build_search_errors].values.join
      assert_match %r{not need rpm file}, @controller.assigns[:build_search_errors].values.join
    end
  end

  test "preview_files" do
    pv_param = "pv_#{@errata.available_product_versions.last.id}"

    brew = mock('Brew')
    Brew.stubs(:get_connection).returns(brew)
    brew.expects(:errors).once.returns({})
    brew.expects(:old_builds_by_package).with(kind_of(Errata), instance_of(ProductVersion)).returns({})
    brew.expects(:build_is_properly_tagged?).with(
      kind_of(Errata), instance_of(ProductVersion), instance_of(BrewBuild)).returns(true)
    # Since Bug 1053533 Errata Tool allows RPM builds with empty product listing
    # to be saved to an advisory.
    ProductListing.expects(:get_brew_product_listings).once.returns({})

    @controller.expects(:find_build_by_rpc).with(@brew_build.nvr, {:cache_only => nil}).returns(@brew_build)

    post :preview_files, :id => @errata.id, pv_param => @brew_build.nvr
    assert_response :success
    assert_equal 1, assigns[:build_count]
    assert_equal 1, assigns[:product_builds].values.count
    assert assigns[:product_builds].values.first.include?(@brew_build)
  end

  test "preview_files using url instead of nvr" do
    pv_param = "pv_#{@errata.available_product_versions.last.id}"

    url = "https://brewweb.engineering.redhat.com/brew/buildinfo?buildID=#{@brew_build.id}"
    brew = mock('Brew')
    Brew.stubs(:get_connection).returns(brew)
    brew.expects(:errors).once.returns({})
    brew.expects(:old_builds_by_package).with(kind_of(Errata), instance_of(ProductVersion)).returns({})
    brew.expects(:build_is_properly_tagged?).with(
      kind_of(Errata), instance_of(ProductVersion), instance_of(BrewBuild)).returns(true)

    ProductListing.expects(:get_brew_product_listings).once.returns({})
    Brew.expects(:get_connection).once.returns(brew)

    @controller.expects(:find_build_by_rpc).with("#{@brew_build.id}", {:cache_only => nil}).returns(@brew_build)

    post :preview_files, :id => @errata.id, pv_param => url
    assert_response :success
    assert_equal 1, assigns[:build_count]
    assert_equal 1, assigns[:product_builds].values.count
    assert assigns[:product_builds].values.first.include?(@brew_build)
  end

  test 'preview_files only shows newest build' do
    pv_param = "pv_#{@errata.available_product_versions.last.id}"

    brew = mock('Brew')
    Brew.stubs(:get_connection).returns(brew)
    brew.expects(:errors).at_least_once.returns({})
    brew.expects(:old_builds_by_package).at_least_once.
      with(kind_of(Errata), instance_of(ProductVersion)).
      returns({})
    brew.expects(:build_is_properly_tagged?).at_least_once.
      with(
        kind_of(Errata),
        instance_of(ProductVersion),
        instance_of(BrewBuild)).
      returns(true)
    ProductListing.expects(:get_brew_product_listings).at_least_once.returns({})

    old_build, new_build, irrelevant_build = ['virtio-win-1.1.16-1.el6',
                                              'virtio-win-1.2.0-1.el6',
                                              'rsh-0.17-76.aa7a_1.1']

    post :preview_files,
         :id => @errata.id,
         pv_param => "#{old_build}\n#{new_build}\n#{irrelevant_build}"

    assert_response :success
    assert_equal 2, assigns[:build_count]
    assert_equal 1, assigns[:product_builds].values.count
    # only newest build shows up
    assert assigns[:product_builds].values.first.map(&:nvr).include?(new_build)
    # old build is removed
    refute assigns[:product_builds].values.first.map(&:nvr).include?(old_build)
    # builds from multiple packages are handled properly.
    assert assigns[:product_builds].values.first.map(&:nvr).include?(irrelevant_build)
  end

  test "brew errors are propagated to search errors in preview files" do
    pv_param = "pv_#{@errata.available_product_versions.last.id}"
    errors = {'buildname' => ['Improperly tagged']}

    brew = mock("Brew")
    brew.expects(:old_builds_by_package).returns({})
    brew.expects(:build_is_properly_tagged?).returns(false)
    brew.expects(:errors).twice.returns(errors)

    Brew.expects(:get_connection).times(2).returns(brew)

    post :preview_files, :id => @errata.id, pv_param => @brew_build.nvr
    assert_response :success
    assert_equal errors, assigns[:build_search_errors]
  end

  test "save builds" do
    pv_id = @errata.available_product_versions.last.id
    build_param = {@brew_build.nvr => {:product_versions => {pv_id => {}}}}

    RpmdiffRun.expects(:schedule_runs).with(instance_of(@errata.class), instance_of(String)).returns([])
    Brew.any_instance.expects(:build_is_properly_tagged?).returns(true)
    # Since Bug 1053533 Errata Tool allows RPM builds with empty product listing
    # to be saved to an advisory.
    ProductListing.expects(:get_brew_product_listings).at_least_once.returns({})

    assert_difference('ErrataBrewMapping.count') do
      post :save_builds, :id => @errata.id, :builds => build_param
      assert_response :success, response.body
      assert_nil flash[:error]
    end
  end

  test "save builds with error" do
    pv = @errata.available_product_versions.last.id
    released_packages_list = {
      :list => [],
      :error_messages => [
        "Build 'A' has newer or equal version of test_package.rpm",
        "Build 'B' has newer or equal version of test_package2.rpm"]}

    ReleasedPackage.expects(:last_released_packages_by_variant_and_arch).at_least_once.returns(released_packages_list)
    Brew.any_instance.expects(:build_is_properly_tagged?).returns(true)

    assert_no_difference('ErrataBrewMapping.count') do
      post :save_builds, :id => @errata.id, :builds => {
        @brew_build.nvr => {:product_versions => {pv => {}}}
      }
    end

    assert_response :success
    assert_match(/Unable to add build '#{@brew_build.nvr}'/, flash[:error])
    released_packages_list[:error_messages].each do |error_message|
      assert_match(/#{error_message}/, flash[:error])
    end
  end

  # See Bug 984598
  test "signed indicator in brewfiles view" do
    indicator_selector = "strong.float-right.tiny"

    # the picked build is not signed
    assert !@brew_build.is_signed?
    # and has only one build attached
    assert_equal 1, @errata.brew_builds.count

    get :list_files, :id=>@errata.id
    assert_response :success
    assert_select indicator_selector, "unsigned"

    # sign the build, which should be reflected in the view.
    key = SigKey.new(:name=>"dummy", :keyid=>"dummy", :sigserver_keyname=>"dummy")
    @brew_build.mark_as_signed(key);
    get :list_files, :id=>@errata.id
    assert_select indicator_selector, "signed"
  end

  test "find a brew build" do
    [:id => BrewBuild.last.id, :nvr => BrewBuild.last.nvr].each do |params|
      post :errata_for_build, :id => BrewBuild.last.id
      assert_response :success
      assert_equal BrewBuild.last.errata, assigns['errata']
    end
  end

  # Bug 485395
  test "removing build from advisory obsoletes related rpmdiff" do
    e = RHBA.find(10808)

    # Initially has a failing score
    assert_equal( {3=>1}, e.rpmdiff_stats )

    post :remove_build, :id => e.build_mappings.first.id
    assert_response :redirect

    # Removing the build obsoleted the test
    assert_equal( {}, e.rpmdiff_stats )
  end

  test "updating build in an advisory doesn't obsolete previous rpmdiff" do
    e = RHBA.find(11036)

    # Start with a clean state according to the current rpmdiff
    # scheduling algorithm, which may be different from when the
    # fixtures were originally created.
    RpmdiffRun.schedule_runs(e)
    e.reload

    assert_equal 1, e.rpmdiff_runs.current.count, 'fixture problem: expected one current rpmdiff run'

    old_rpmdiff_run = e.rpmdiff_runs.current.first
    old_build = old_rpmdiff_run.brew_build
    assert_equal 'net-snmp-5.3.2.2-11.el5', old_build.nvr, 'fixture problem: different build than expected'

    # bump the release; must create new RPMs as well (rpmdiff scheduling bails out if rpms are missing)
    new_build = BrewBuild.create!(
      :package => old_build.package,
      :sig_key => old_build.sig_key,
      :nvr => 'net-snmp-5.3.2.2-12.el5',
      :epoch => '1',
      :version => '5.3.2.2',
      :release => '12'
    )
    old_build.brew_rpms.each do |rpm|
      new_name = rpm.name.gsub(/-11\.el5/, '-12.el5')
      new_build.brew_rpms << BrewRpm.new(:name => new_name, :arch => rpm.arch, :package => rpm.package, :id_brew => rpm.id_brew*1000)
    end
    new_build.save!

    pv = old_build.errata_brew_mappings.first.product_version

    post :save_builds, :id => e.id, "pv_#{pv.id}" => new_build.id
    assert_response :success, response.body

    old_rpmdiff_run.reload
    refute old_rpmdiff_run.obsolete?, "Updating build #{old_build.nvr} to #{new_build.nvr} incorrectly obsoleted old rpmdiff run"
  end

  test 'buildroot push request and cancel have access control' do
    # Assumption: we've used the default setup and have the Devel role.
    # The following should work only for the qa/secalert/releng roles:
    #   POST "/brew/cancel_buildroot_push/55984"
    #   POST "/brew/request_buildroot_push/23816"
    # Other roles should receive: 401 Unauthorized
    # See also test/integration/errata_builds_test for related GUI,
    # which also hits the user-is-authorized cases.
    post :request_buildroot_push, :id => 23816
    assert_response :unauthorized, "Devel user should be unable to request buildroot push"

    post :cancel_buildroot_push, :id => 55984
    assert_response :unauthorized, "Devel user should be unable to cancel buildroot push"
  end

  test 'check_signatures updates signature state for RPMs only' do
    e = @errata_rpm_and_nonrpm

    rpm_count = e.build_mappings.for_rpms.count

    ErrataBrewMapping.any_instance.expects(:update_sig_state).times(rpm_count)
    post :check_signatures, :id => e
    assert_response :redirect, response.body
  end

  # list_files has been designed to return the files grouped by variant and arch.
  # Those concepts don't make sense for non-rpm files at the moment, so files other
  # than RPMs are simply not returned by this method.
  test "list_files json returns nothing for advisory with only non-rpm content" do
    e = @errata_nonrpm_only

    get :list_files, :id => e, :format => :json
    assert_response :success

    obj = JSON.load(response.body)
    assert_equal({}, obj)
  end

  test "list_files json returns rpm content only for advisory with mixed content" do
    e = @errata_rpm_and_nonrpm

    get :list_files, :id => e, :format => :json
    assert_response :success

    obj = JSON.load(response.body)
    assert_equal({
      "RHEL-7.0-Supplementary"=>
        [{"rhel-server-docker-7.0-22"=>{
          "7Client-Client"=>
            {"noarch"=>["rhel-server-docker-7.0-22.noarch.rpm"],
             "SRPMS"=>["rhel-server-docker-7.0-22.src.rpm"]},
          "7Server-Server"=>
            {"noarch"=>["rhel-server-docker-7.0-22.noarch.rpm"],
             "SRPMS"=>["rhel-server-docker-7.0-22.src.rpm"]}}
        }]
    }, obj)
  end

  test "list_files json returns docker image files" do
    e = Errata.find(21100)
    assert e.has_docker?

    get :list_files, :id => e, :format => :json
    assert_response :success

    obj = JSON.load(response.body)
    assert_equal({
      "RHEL-7.1.Z"=>
        [{"rhel-server-docker-7.1-3"=>{
          "7Server-7.1.Z"=>
            {"x86_64"=>["rhel-server-docker-7.1-3.x86_64.tar.gz"]}
          }
        }]
    }, obj)
  end

  # reloading only files of a particular type is not supported;
  # ensure reload_build reloads all the file types
  test 'reload_build reloads all mappings for the advisory and build' do
    e = RHBA.find(16396)
    mappings = e.build_mappings.to_a

    assert mappings.length > 1

    mapping = mappings.first
    mappings_rel = mock()

    ErrataBrewMapping.expects(:find).with{|arg1,*rest| arg1.to_s == mapping.id.to_s}.at_least_once.returns(mapping)
    mapping.expects(:errata).at_least_once.returns(e)
    e.expects(:build_mappings).at_least_once.returns(mappings_rel)
    mappings_rel.expects(:where).with(:brew_build_id => mapping.brew_build_id).at_least_once.returns(mappings)

    mappings.each{|m| m.expects(:reload_files).once}

    post :reload_build, :id => mapping.id
    assert_response :redirect, response.body
  end

  test 'put_file_meta_title creates BrewFileMeta OK' do
    e = Errata.find(16396)

    assert e.brew_file_meta.none?

    file = e.brew_files.nonrpm.first

    assert_difference('BrewFileMeta.count', 1) do
      xhr(:post, :put_file_meta_title,
        :id => e,
        :file => file.id,
        :title => 'some file')
      assert_response :success, response.body
    end

    e.reload
    e.brew_file_meta.first.tap{|meta|
      assert_equal file, meta.brew_file
      assert_equal 'some file', meta.title
    }
  end

  test 'put_file_meta_title updates BrewFileMeta OK' do
    e = Errata.find(16396)

    file = e.brew_files.nonrpm.first

    BrewFileMeta.create!(:errata => e, :brew_file => file, :title => 'some title')

    assert_no_difference('BrewFileMeta.count') do
      xhr(:post, :put_file_meta_title,
        :id => e,
        :file => file.id,
        :title => 'other title')
      assert_response :success, response.body
    end

    e.reload
    e.brew_file_meta.first.tap{|meta|
      assert_equal file, meta.brew_file
      assert_equal 'other title', meta.title
    }
  end

  test 'put_file_meta_title reports errors as JSON' do
    e = Errata.find(16396)

    file = e.brew_files.nonrpm.first

    assert_no_difference('BrewFileMeta.count') do
      xhr(:post, :put_file_meta_title,
        :id => e,
        :file => file.id,
        :title => 'x')
      assert_response :bad_request, response.body
    end

    data = JSON.load(response.body)
    assert_equal({'errors' => {'title' => ['is too short (minimum is 5 characters)']}}, data)
  end

  test 'put_file_meta_title rejects if filelist is locked' do
    e = Errata.find(16409)

    assert e.filelist_locked?, 'fixture problem'

    file = e.brew_files.nonrpm.first

    xhr(:post, :put_file_meta_title,
      :id => e,
      :file => file.id,
      :title => 'a new title')
    assert_response :redirect, response.body

    assert_match %r{Filelist is locked}, flash[:error]
  end

  test 'put_file_meta_rank creates BrewFileMeta OK' do
    e = Errata.find(16396)

    assert e.brew_file_meta.none?

    files = e.brew_files.nonrpm.order('id DESC')

    assert_difference('BrewFileMeta.count', files.count) do
      xhr(:post, :put_file_meta_rank,
        :id => e,
        :brew_file_order => files.map(&:id).map(&:to_s).join(','))
      assert_response :success, response.body
    end

    e.reload

    actual_order = e.brew_file_meta.order('rank ASC').map(&:brew_file)
    assert_equal files, actual_order
  end

  test 'put_file_meta_rank updates BrewFileMeta OK' do
    e = Errata.find(16396)

    files = e.brew_files.nonrpm.order('id ASC').to_a
    assert_equal 3, files.length

    BrewFileMeta.create!(
      :errata => e,
      :brew_file => files[0],
      :rank => 10)

    BrewFileMeta.create!(
      :errata => e,
      :brew_file => files[1],
      :rank => 8)

    BrewFileMeta.create!(
      :errata => e,
      :brew_file => files[2],
      :rank => 12)

    # verify the initial ordering ...
    assert_equal [files[1], files[0], files[2]], e.reload.brew_file_meta.order('rank ASC').map(&:brew_file)

    assert_no_difference('BrewFileMeta.count') do
      xhr(:post, :put_file_meta_rank,
        :id => e,
        :brew_file_order => [1,2,0].map{|i| files[i].id.to_s}.join(','))
      assert_response :success, response.body
    end

    # and ensure reordered as requested
    assert_equal [files[1], files[2], files[0]], e.reload.brew_file_meta.order('rank ASC').map(&:brew_file)
  end

  test 'put_file_meta_rank rejects if filelist is locked' do
    e = Errata.find(16409)

    assert e.filelist_locked?, 'fixture problem'

    file = e.brew_files.nonrpm.first

    xhr(:post, :put_file_meta_rank,
      :id => e,
      :brew_file_order => file.id)
    assert_response :redirect, response.body

    assert_match %r{Filelist is locked}, flash[:error]
  end

  test 'can set title and rank in any order' do
    e = Errata.find(16396)

    files = e.brew_files.nonrpm.order('id ASC').to_a
    assert_equal [], e.brew_file_meta.to_a

    xhr(:post, :put_file_meta_title,
      :id => e,
      :file => files[0].id,
      :title => 'first file')
    assert_response :success, response.body

    xhr(:post, :put_file_meta_title,
      :id => e,
      :file => files[2].id,
      :title => 'third file')
    assert_response :success, response.body
    e.reload

    # two meta should now exist, but none of them are complete
    assert_equal 2, e.brew_file_meta.length
    assert_equal 0, e.brew_file_meta.complete.length

    xhr(:post, :put_file_meta_rank,
      :id => e,
      :brew_file_order => files.reverse.map(&:id).map(&:to_s).join(','))
    assert_response :success, response.body
    e.reload

    # all the files now have meta, and just the one missing title is
    # incomplete
    assert_equal 3, e.brew_file_meta.length
    assert_equal 2, e.brew_file_meta.complete.length

    xhr(:post, :put_file_meta_title,
      :id => e,
      :file => files[1].id,
      :title => 'second file')
    assert_response :success, response.body
    e.reload

    # everything complete now
    meta = e.brew_file_meta.order('rank ASC')

    assert_equal 3, meta.length
    assert_equal 3, meta.complete.length

    assert_equal([
        # ranked them in reverse order
        {:rank => 1, :title => 'third file',  :brew_file_id => files[2].id},
        {:rank => 2, :title => 'second file', :brew_file_id => files[1].id},
        {:rank => 3, :title => 'first file',  :brew_file_id => files[0].id},
      ],
      meta.to_a.map{|m| m.attributes.slice(*%w[rank title brew_file_id]).deep_symbolize_keys}
    )
  end

  test "reselect contents from a build" do
    Brew.any_instance.stubs(:list_tags).with(@rpm_and_nonrpm_mapping.brew_build).returns(%w[supp-rhel-7.0-candidate])
    Brew.any_instance.stubs(:get_valid_tags).with(@errata_rpm_and_nonrpm, @rpm_and_nonrpm_mapping.product_version).returns(%w[supp-rhel-7.0-candidate])

    old_content_types = @errata_rpm_and_nonrpm.generate_content_types
    assert_equal %w(ks rpm tar), old_content_types

    post :save_reselect_build, :id=>@errata_rpm_and_nonrpm, :builds => {
      "#{@rpm_and_nonrpm_mapping.brew_build.nvr}" => {
        "product_versions" => {
          "#{@rpm_and_nonrpm_mapping.product_version.name}" => {
             "file_types" => ["rpm", "ks"]
          }
        }
      }
    }

    assert_response :success

    update_content_types = @errata_rpm_and_nonrpm.reload.content_types
    assert_equal %w(ks rpm), update_content_types
  end

  test "removing docker build updates content_types" do
    docker_errata = Errata.find(21101)
    assert_equal ['docker'], docker_errata.generate_content_types

    mapping = docker_errata.build_mappings.first
    nvr = docker_errata.brew_builds.first.nvr

    # Remove the build
    post :remove_build, :id => mapping

    assert_response :redirect
    assert_redirected_to controller: :brew, action: :list_files, id: docker_errata

    assert docker_errata.reload.content_types.empty?
  end

  test "list_files json for pdc advisory" do
    e = PdcRHBA.find(21131)

    o1 = OpenStruct.new(:x86_64 => OpenStruct.new(:"ceph" => ["src"], :"ceph-common" => ["x86_64"], :"ceph-base" => ["x86_64"]))
    o = OpenStruct.new(:MON => o1, :OSD => o1 )
    PdcErrataReleaseBuild.any_instance.expects(:cached_product_listings).returns(o)

    get :list_files, :id => e, :format => :json
    assert_response :success

    obj = JSON.load(response.body)
    assert_equal({
      "ceph-2.1-updates@rhel-7"=>
        [{"ceph-10.2.3-17.el7cp"=>{
          "MON"=>
            {"SRPMS"=>["ceph-10.2.3-17.el7cp.src.rpm"],
             "x86_64"=>["ceph-base-10.2.3-17.el7cp.x86_64.rpm", "ceph-common-10.2.3-17.el7cp.x86_64.rpm"]},
          "OSD"=>
            {"SRPMS"=>["ceph-10.2.3-17.el7cp.src.rpm"],
             "x86_64"=>["ceph-base-10.2.3-17.el7cp.x86_64.rpm", "ceph-common-10.2.3-17.el7cp.x86_64.rpm"]}
        }}]
    }, obj)
  end

end
