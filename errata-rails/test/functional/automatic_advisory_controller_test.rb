require 'test_helper'

class AutomaticAdvisoryControllerTest < ActionController::TestCase
  #
  # Bug: 998852
  # When creating the AutomaticallyFiledAdvisory, we only want to
  # include bugs which are valid.
  #
  test 'create automatic advisory and avoid invalid bugs' do
    auth_as admin_user
    release = Release.find_by_name('RHEL-5.7.0')
    b4r = BugsForRelease.new(release)
    bugs = b4r.eligible_bugs.where(
      :package_id => Package.find_by_name('kernel').id,
      :bug_status => 'MODIFIED',
      :keywords   => '')
    bugs.first.keywords = 'TestOnly'
    bugs.first.save!

    post :create_quarterly_update,
    :pkgs => {Package.find_by_name('kernel') => '1'},
    :type => 'RHBA',
    :release => {'id' => release.id},
    :product => {:id => Product.find_by_short_name('RHEL')}
    assert_redirected_to :controller=>:errata, :action=>:view, :id=>Errata.last
  end

  test "filter package lists per product" do
    auth_as devel_user
 
    post :qu_for_product, :product => { :id => Product.find_by_short_name('RHEL').id }
    assert_response :success
  end

  test "filter package lists by release" do
    auth_as devel_user

    post :packages_for_release, :release => {:id => Release.find_by_name('RHEL-5.7.0').id}
    assert_response :success
  end

  test 'new page is working for legacy' do
    auth_as devel_user
    get :new_qu
    assert_response :success
  end

  test 'new page is working for pdc' do
    auth_as devel_user
    get :new_qu_pdc
    assert_response :success
  end

  test "ineligible bug display" do
    auth_as devel_user
    release = Release.find_by_name('RHEL-6.1.0')
    product = release.product
    b4r = BugsForRelease.new(release)

    post :new_qu, :release => {:id => release.id}, :product => {:id => product.id}, :show_ineligible_packages => 1
    assert_response :success

    # Bugs appear 3 different ways in the UI: under a package with some ineligible and eligible
    # bugs, as a) eligible or b) ineligible, and c) under a package with ineligible bugs only.
    # Cover all those cases.

    # These bugs are eligible/ineligible, for the same package.
    systemtap_elig = Bug.find(618867)
    systemtap_inelig = Bug.find(600382)
    # This bug is ineligible, in a package with no eligible bugs
    evolution_inelig = Bug.find(666875)

    # prove the conditions mentioned above
    ineligible_all = b4r.ineligible_bugs_by_package
    eligible_all = b4r.eligible_bugs_by_package
    assert_equal systemtap_elig.package, systemtap_inelig.package
    assert ineligible_all.keys.include?(systemtap_elig.package)
    assert eligible_all.keys.include?(systemtap_elig.package)

    assert ineligible_all.keys.include?(evolution_inelig.package)
    refute eligible_all.keys.include?(evolution_inelig.package)

    # Verify display
    assert_match eligible_bug_pattern(systemtap_elig), response.body
    assert_match ineligible_bug_pattern(systemtap_inelig), response.body
    assert_match ineligible_bug_pattern(evolution_inelig), response.body
  end

  test 'erratum automatically assigned to a batch' do
    auth_as admin_user
    release = Release.find_by_name!('RHEL-6.1.0')
    assert release.enable_batching?, "Release does not have batching enabled"

    post :create_quarterly_update,
    :pkgs => {Package.find_by_name!('kernel') => '1'},
    :type => 'RHBA',
    :release => {'id' => release.id},
    :product => {:id => Product.find_by_short_name!('RHEL')}
    assert_redirected_to :controller=>:errata, :action=>:view, :id=>Errata.last

    # Advisory has a batch_id set
    assert Errata.last.batch_id.present?
  end

  def eligible_bug_pattern(bug)
    %r{
        \b#{bug.id}</a>
        \s*
        <span>
        #{ERB::Util.h Regexp.quote(bug.short_desc)}
        \s*
        </span>
    }mx
  end

  def ineligible_bug_pattern(bug)
    %r{
        \b#{bug.id}</a>
        \s*
        <span>
        #{ERB::Util.h Regexp.quote(bug.short_desc)}
        \s*
        <a[^>]+>Why\?</a>
    }mx
  end

end
