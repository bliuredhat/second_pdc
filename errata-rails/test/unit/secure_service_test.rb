require 'test_helper'

class SecureServiceTest < ActiveSupport::TestCase
  setup do
    @service = SecureService.new

    @errata = rhba_async
    @product_version = ProductVersion.find_by_name('RHEL-6')
    @brew_build = BrewBuild.find_by_nvr('autotrace-0.31.1-26.el6')
    refute @errata.brew_builds.include?(@brew_build)
  end

  test "basic add bugs for release" do
    with_current_user(devel_user) do
      bug_ids = [693759]
      # net_smtp bug and RHEL 5.7 advisory in NEW_FILES
      res = @service.add_bugs_to_errata(11036, bug_ids)
      assert_equal  "Added the following bugs:\nbug 693759 - Log files fill up quickly when running hp-snmp-agents", res
    end
  end

  test "add bugs without approved components bug 990318" do
    pkg = Package.find_or_create_by_name 'RPMs'
    bug1 = Bug.create!(:bug_status => 'MODIFIED', :package => pkg, :short_desc => 'test bug 1')
    bug2 = Bug.create!(:bug_status => 'MODIFIED', :package => pkg, :short_desc => 'test bug 2')
    with_current_user(devel_user) do
      res = @service.add_bugs_to_errata(rhba_async.id, [bug1.id, bug2.id])
      assert_equal "Added the following bugs:\nbug #{bug1.id} - test bug 1\nbug #{bug2.id} - test bug 2", res
    end
  end

  def setup_brew_tag_expects(list_tag, valid_tag)
    Brew.any_instance.expects(:list_tags).with(@brew_build).once.returns([list_tag])
    Brew.any_instance.expects(:get_valid_tags).with(@errata, @product_version).returns([valid_tag])
  end

  test "update builds when build is properly tagged" do
    setup_brew_tag_expects('foo', 'foo')
    with_current_user(devel_user) do
      response = @service.update_brew_build(@errata.shortadvisory, @product_version.name, @brew_build.nvr)
      assert_match /Added build #{@brew_build.nvr}/, response
      assert @errata.reload.brew_builds.include?(@brew_build)
    end
  end

  test "update builds when build is not properly tagged" do
    setup_brew_tag_expects('foo', 'bar')
    with_current_user(devel_user) do
      response = @service.update_brew_build(@errata.shortadvisory, @product_version.name, @brew_build.nvr)
      assert_match /does not have any of the valid tags/, response
      refute @errata.reload.brew_builds.include?(@brew_build)
    end
  end

  test "add bad CVE bugs by secalert user should be permitted" do
    bad_cve_test(secalert_user)
  end

  test "add bad CVE bugs by non-secalert user should be permitted" do
    bad_cve_test(devel_user)
  end

  def bad_cve_test(user)
    bug = Bug.find(684919)
    errata = RHSA.find(11149)
    res = with_current_user(user) do
      @service.add_bugs_to_errata(errata.id, [bug.id])
    end
    assert errata.reload.bugs.include?(bug)
    assert_equal(
      "Added the following bugs:\nbug 684919 - CVE-2011-1011 selinux-policy: " +
        'insecure temporary directory handling in seunshare [rhel-6.1]',
      res)
  end
end
