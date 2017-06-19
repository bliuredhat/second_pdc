require 'test_helper'

class PackageControllerTest < ActionController::TestCase
  setup do
    auth_as releng_user
  end

  test "get a list of match packages by json" do
    key = 'open'
    get :list, :name => key, :format => :json
    assert_response :ok
    results = JSON.parse(response.body).map{|r| r['name']}
    assert_equal 81, results.count, "Fixture problem. The number of expected packages no longer match"
    assert_equal [], results.select{|r| r !~ /#{key}/}, "Results contain unmatch keyword"
  end

  test "search for blank package" do
    get :show, :name => nil
    assert_redirected_to :action => :index
    assert_equal 'No id or name parameter given', flash[:alert]
    flash.clear

    # (In reality I think blank params turn into nils)
    get :show, :name => ''
    assert_redirected_to :action => :index
    assert_equal 'Empty id or name parameter given', flash[:alert]
  end

  test "search for non-existent package" do
    get :show, :name => 'foobar'
    assert_redirected_to :action => :index
    assert_equal "Couldn't find Package with name = foobar", flash[:alert]
  end

  test "search for existing package" do
    get :show, :name => 'ruby'
    assert_response :success
    assert_equal assigns[:package], Package.find_by_name('ruby')
  end

  test "search a package related to PDC data" do
    package_name = 'ceph'
    @package = Package.find_by_name(package_name)
    maps =PdcErrataReleaseBuild.where(:brew_build_id=>@package.brew_builds)

    assert maps.count == 2

    get :show, :name => package_name
    assert_response :success, response.body

    assert(response.body.index("ceph"), response.body)
    assert(response.body.index("[PDC]"), response.body)
  end

  test "find existing package from index page search" do
    post :index, :pkg => { :name => 'ruby' }
    assert_redirected_to :action => :show, :name => 'ruby'
  end

  test "find existing package from index page search with whitespace" do
    post :index, :pkg => { :name => ' ruby  ' }
    assert_redirected_to :action => :show, :name => 'ruby'
  end

  test "find non-existent package from index page search" do
    post :index, :pkg => { :name => 'foobar' }
    assert_redirected_to :action => :index
    assert_equal 'No such package foobar', flash[:alert]
  end

  test "package list by qe team" do
    qr = QualityResponsibility.find_by_name('BaseOS QE - Applications')
    pkg = Package.find_by_name('javassist')
    assert_equal qr, pkg.quality_responsibility, 'fixture problem'

    get :qe_team, :id => qr.url_name
    assert_response :success
    assert_select 'h1', "Packages for #{qr.name}"
    assert_select 'table a', qr.default_owner.short_to_s
    assert_select 'table.bug_list a', pkg.name
  end

  # Bug 1199945
  test "show doesn't crash if product version FTP exclusions exist" do
    auth_as admin_user

    ex = FtpExclusion.find(958)
    assert_not_nil ex.product_version_id, 'fixture problem'

    get :show, :name => ex.package.name
    assert_response :success, response.body
    assert_equal assigns[:package], ex.package
  end
end
