require 'test_helper'

class PushCdnLibTest < ActiveSupport::TestCase
  setup do
    # Create non primary cdn repos for testing
    repos = [
      ["rhel-6-server-fastrack-#ct-rpms__6Server__x86_64", "x86_64", "FastTrackCdnRepo", "6Server"],
      ["rhel-6-server-fastrack-#ct-rpms__6Server__i386",   "i386",   "FastTrackCdnRepo", "6Server"],
      ["rhel-6-server-eus-#ct-rpms__6Server__x86_64",      "x86_64", "EusCdnRepo",       "6Server-LoadBalancer"],
      ["rhel-6-server-eus-#ct-rpms__6Server__i386",        "i386",   "EusCdnRepo",       "6Server-LoadBalancer"],
      ["rhel-6-server-longlife-#ct-rpms__6Server__x86_64", "x86_64", "LongLifeCdnRepo",  "6Server-LoadBalancer"],
      ["rhel-6-server-longlife-#ct-rpms__6Server__i386",   "i386",   "LongLifeCdnRepo",  "6Server-LoadBalancer"],
    ]

    @non_primary_repos= []
    repos.each do |repo|
      [:CdnBinaryRepo, :CdnSourceRepo, :CdnDebuginfoRepo].each do |type|
        name = repo[0].gsub('#ct', type.to_s.gsub(/Cdn|Repo|Binary/, '').downcase)
        name = name.sub('--', '-')
        @non_primary_repos << type.to_s.constantize.create!(:name => name,
                                                            :arch =>  Arch.find_by_name(repo[1]),
                                                            :release_type => repo[2],
                                                            :variant => Variant.find_by_name(repo[3]),
                                                            :has_stable_systems_subscribed => true)
      end
    end

    @expected_rpms_6_server_fast= {
      "rhel-6-server-fastrack-rpms__6Server__x86_64"           => [:x86_64_i686_rpms, :x86_64_rpms],
      "rhel-6-server-fastrack-source-rpms__6Server__x86_64"    => [:srpm],
      "rhel-6-server-fastrack-debuginfo-rpms__6Server__x86_64" => [:x86_64_debuginfo],
      "rhel-6-server-fastrack-rpms__6Server__i386"             => [:i386_rpms],
    }

    @expected_rpms_6_server_base = {
      "rhel-6-server-source-rpms__6Server__x86_64"    => [:srpm],
      "rhel-6-server-rpms__6Server__x86_64"           => [:x86_64_i686_rpms, :x86_64_rpms],
      "rhel-6-server-debuginfo-rpms__6Server__x86_64" => [:x86_64_debuginfo],
      "rhel-6-server-rpms__6Server__i386"             => [:i386_rpms],
      "rhel-6-server-rpms__6Server__ppc64"            => [:ppc64_rpms, :ppc_rpms],
      "rhel-6-server-rpms__6Server__s390x"            => [:s390x_rpms, :s390_rpms],
    }

    @expected_rpms_6_base = {
      "rhel-6-client-source-rpms__6Client__x86_64"    => [:srpm],
      "rhel-6-server-rpms__6Server__i386"             => [:i386_rpms],
      "rhel-6-server-rpms__6Server__ppc64"            => [:ppc64_rpms, :ppc_rpms],
      "rhel-6-server-rpms__6Server__s390x"            => [:s390x_rpms, :s390_rpms],
      "rhel-6-client-rpms__6Client__x86_64"           => [:client_x86_64_rpms, :client_i686_rpms],
      "rhel-6-client-rpms__6Client__i386"             => [:client_i386_rpms],
      "rhel-6-server-debuginfo-rpms__6Server__i386"   => [:i386_debuginfo],
      "rhel-6-server-debuginfo-rpms__6Server__ppc64"  => [:ppc64_debuginfo],
      "rhel-6-server-debuginfo-rpms__6Server__s390x"  => [:s390x_debuginfo],
      "rhel-6-client-debuginfo-rpms__6Client__x86_64" => [:x86_64_debuginfo],
    }.merge(@expected_rpms_6_server_base)

    @expected_rpms_6_fast = {
      "rhel-6-server-fastrack-debuginfo-rpms__6Server__i386"   => [:i386_debuginfo],
      "rhel-6-server-fastrack-rpms__6Server__i386"             => [:i386_rpms],
      "rhel-6-server-fastrack-source-rpms__6Server__i386"      => [:srpm],
    }.merge(@expected_rpms_6_server_fast)

    @expected_rpms_6_5_z_base = {
      "rhel-6-server-eus-source-rpms__6_DOT_5__x86_64" => [:srpm],
      "rhel-6-server-eus-debug-rpms__6_DOT_5__x86_64"  => [:x86_64_debuginfo],
      "rhel-6-server-eus-rpms__6_DOT_5__x86_64"        => [:x86_64_i686_rpms, :x86_64_rpms],
    }

    @expected_rpms_6        = @expected_rpms_6_base.merge(@expected_rpms_6_fast)
    @expected_rpms_6_server = @expected_rpms_6_server_base.merge(@expected_rpms_6_server_fast)
    @expected_rpms_6_5_z    = @expected_rpms_6_server_base.merge(@expected_rpms_6_5_z_base)

    # generate the expected cdn repos and rpms hash for most test cases
    @expected_repos = get_expected_outputs(@expected_rpms_6_base, "1.0.1", "1.el6")
    @expected_released_repos = get_expected_outputs(@expected_rpms_6, "1.0.1", "1.el6")

    cobbler_path    = "/mnt/redhat/brewroot/packages/cobbler/2.0.7/21.el6sat/data/signed/fd431d51"
    koan_rpm        = "#{cobbler_path}/noarch/koan-2.0.7-21.el6sat.noarch.rpm"
    cobbler_src_rpm = "#{cobbler_path}/src/cobbler-2.0.7-21.el6sat.src.rpm"
    cobbler_rpm     = "#{cobbler_path}/noarch/cobbler-2.0.7-21.el6sat.noarch.rpm"

    @rhn_tools_rpms = {
      "rhn-tools-for-rhel-6-server-source-rpms__x86_64" => [cobbler_src_rpm].to_set,
      "rhn-tools-for-rhel-6-server-rpms__x86_64"        => [koan_rpm, cobbler_rpm].to_set,
    }

    # clean up any released rpms for this package before testing
    package = Package.find_by_name("krb5")
    ReleasedPackage.where(:package_id => package).delete_all

    # create test errata (1 main-stream and 1 z-stream)
    @errata = Hash.new{|h,k| h[k] = {}}
    product_listing_id = 29391
    {
     :rhel_6_3_0 => {:rhel => "RHEL-6.3.0", :rpm_ver => "1.0.1", :rpm_rel => "1.el6",     :product_version => "RHEL-6"},
     :rhel_6_5_z => {:rhel => "RHEL-6.5.z", :rpm_ver => "2.0.1", :rpm_rel => "1.el6_5.1", :product_version => "RHEL-6.5.z"},
    }.each_pair do |k,v|
      @errata[k] = create_test_errata(v[:rhel], v[:rpm_ver], v[:rpm_rel], product_listing_id, v[:product_version])
    end

    # Use cached product listings only
    ProductListing.stubs(:get_brew_product_listings => {})
  end

  def create_test_errata(rhel_release, rpm_version, rpm_release, product_listing_id, product_version_name)
    brew_build = create_test_brew_build(product_listing_id, rpm_version, rpm_release, product_version_name)
    rhba = create_test_rhba(rhel_release, brew_build.nvr)
  end

  def prepare_expected_released_packages(errata)
    expected_packages = ReleasedPackage.where(:current => 1, :errata_id => errata)
    expected_results = Hash.new{ |hash,key| hash[key] = Set.new }

    expected_packages.each do |p|
      repos = CdnRepoLink.joins(:cdn_repo).\
        where('cdn_repo_links.variant_id = ? and cdn_repos.arch_id = ?', p.variant, p.arch).\
        map{|l| l.cdn_repo}
      repos.each do |repo|
        if repo.type == 'CdnDebuginfoRepo' && p.full_path =~ /debuginfo/
          expected_results[repo.name].merge(p.full_path)
        elsif repo.type == 'CdnSourceRepo' && p.full_path =~ /src\.rpm/
          expected_results[repo.name].merge(p.full_path)
        elsif repo.type == 'CdnBinaryRepo' && p.full_path !~ /debuginfo/ && p.full_path !~ /src\.rpm/
          expected_results[repo.name].merge(p.full_path)
        end
      end
    end
    return expected_results
  end

  def get_expected_outputs(template, rpm_version, rpm_release)
    path = "/mnt/redhat/brewroot/packages/krb5/#{rpm_version}/#{rpm_release}"
    ldap        = "krb5-server-ldap"
    libs        = "krb5-libs"
    devel       = "krb5-devel"
    pkinit      = "krb5-pkinit-openssl"
    server      = "krb5-server"
    workstation = "krb5-workstation"
    debuginfo   = "krb5-debuginfo"

    all_rpms    = [ldap, libs, devel, pkinit, server, workstation]
    ldap_rpms   = [devel, libs, ldap]
    pkinit_rpms = [libs, pkinit, workstation]

    file_list = {
      :srpm               => ["#{path}/src/krb5-#{rpm_version}-#{rpm_release}.src.rpm"],
      :x86_64_rpms        => make_rpm_paths(path, rpm_version, rpm_release, ["x86_64"], all_rpms),
      :x86_64_i686_rpms   => make_rpm_paths(path, rpm_version, rpm_release, ["i686"],   ldap_rpms),
      :i686_rpms          => make_rpm_paths(path, rpm_version, rpm_release, ["x86_64"], pkinit_rpms),
      :i386_rpms          => make_rpm_paths(path, rpm_version, rpm_release, ["i686"],   pkinit_rpms + [devel, server, ldap]),
      :s390x_rpms         => make_rpm_paths(path, rpm_version, rpm_release, ["s390x"],  all_rpms),
      :ppc64_rpms         => make_rpm_paths(path, rpm_version, rpm_release, ["ppc64"],  all_rpms),
      :s390_rpms          => make_rpm_paths(path, rpm_version, rpm_release, ["s390"],   ldap_rpms),
      :ppc_rpms           => make_rpm_paths(path, rpm_version, rpm_release, ["ppc"],    ldap_rpms),
      :client_x86_64_rpms => make_rpm_paths(path, rpm_version, rpm_release, ["x86_64"], pkinit_rpms),
      :client_i386_rpms   => make_rpm_paths(path, rpm_version, rpm_release, ["i686"],   pkinit_rpms),
      :client_i686_rpms   => make_rpm_paths(path, rpm_version, rpm_release, ["i686"],   [libs]),
      :x86_64_debuginfo   => make_rpm_paths(path, rpm_version, rpm_release, ["x86_64", "i686"], [debuginfo]),
      :i386_debuginfo     => make_rpm_paths(path, rpm_version, rpm_release, ["i686"],           [debuginfo]),
      :ppc64_debuginfo    => make_rpm_paths(path, rpm_version, rpm_release, ["ppc64", "ppc"],   [debuginfo]),
      :s390x_debuginfo    => make_rpm_paths(path, rpm_version, rpm_release, ["s390x", "s390"],  [debuginfo]),
    }

    return template.each_with_object(Hash.new{|h,k| h[k] = SortedSet.new}) do |(cdn_repo, files), h|
      h[cdn_repo].merge(files.map{|f| file_list[f]}.flatten)
    end
  end

  def make_rpm_paths(path, rpm_version, rpm_release, arches, rpm_names)
    list = []
    arches.each do |arch|
      rpm_names.each do |name|
        list << "#{path}/#{arch}/#{name}-#{rpm_version}-#{rpm_release}.#{arch}.rpm"
      end
    end
    return list
  end

  def do_not_push_to_cdn(errata)
    package = errata.build_mappings.first.brew_build.package
    variant = Variant.find_by_name('6Server')
    # don't push to cdn
    PackageRestriction.create!(:package => package , :variant => variant, :push_targets => [])
    rejected_repos = variant.cdn_repos.map(&:name)
  end

  def assert_cdn_repos_match(expected_repos, actual_repos)
    assert !actual_repos.empty?
    assert_array_equal expected_repos.keys, actual_repos.keys

    actual_repos.each_pair do |repo_name, files|
      assert_array_equal expected_repos[repo_name], files
    end
  end

  test "get packages in a repo by errata" do
    errata = @errata[:rhel_6_3_0]
    repo = CdnRepo.find_by_name('rhel-6-server-source-rpms__6Server__x86_64')
    repo_files = Push::Cdn.get_packages_by_errata(errata, repo)
    assert_equal 1, repo_files.count

    repo_files.each_pair do |repo_name, files|
      assert_equal repo.name, repo_name
      #should have only 1 source rpm file
      assert_equal 1, files.count
      assert_equal 'krb5-1.0.1-1.el6.src.rpm', File.basename(files.to_a[0])
    end
  end

  test "get all packages by errata" do
    errata = @errata[:rhel_6_3_0]
    actual_repos = Push::Cdn.get_packages_by_errata(errata)

    assert_cdn_repos_match(@expected_repos, actual_repos)
  end

  test "get released packages in a repo by errata" do
    errata = @errata[:rhel_6_3_0]

    repo = CdnRepo.find_by_name('rhel-6-server-source-rpms__6Server__x86_64')
    repo_files = Push::Cdn.get_released_packages_by_errata(errata, repo)

    # assume it is a new package, no previously released package yet
    assert_equal({}, repo_files)

    # ship the packages now
    ship_test_errata_packages(errata)

    repo_files = Push::Cdn.get_released_packages_by_errata(errata, repo)

    assert_equal 1, repo_files.count

    repo_files.each_pair do |repo_name, files|
      assert_equal repo.name, repo_name
      # should have only 1 source rpm file
      assert_equal 1, files.count
      assert_equal 'krb5-1.0.1-1.el6.src.rpm', File.basename(files.to_a[0])
    end
  end

  test "get all released packages by errata" do
    errata = @errata[:rhel_6_3_0]
    actual_repos = Push::Cdn.get_released_packages_by_errata(errata)

    # assume it is a new package, no previously released package yet
    assert_equal({}, actual_repos)

    # ship the packages now
    ship_test_errata_packages(errata)

    actual_repos = Push::Cdn.get_released_packages_by_errata(errata)

    assert_cdn_repos_match(@expected_released_repos, actual_repos)
  end

  test "get cdn repos for normal errata" do
    errata = @errata[:rhel_6_3_0]
    errata.release.stubs(:is_fasttrack?).returns(false)
    errata.release.stubs(:is_async?).returns(false)
    ProductVersion.any_instance.stubs('is_zstream?').returns(false)

    (results, mapped) = Push::Cdn.cdn_repos_for_errata(errata)

    assert_equal @expected_repos.keys.sort, (results + mapped).map(&:name).sort
  end

  test "get cdn repos for fasttrack errata" do
    errata = @errata[:rhel_6_3_0]
    errata.release.stubs(:is_fasttrack?).returns(true)

    expected_repos = @non_primary_repos.reject{|r| r.release_type != 'FastTrackCdnRepo'}
    (results, mapped) = Push::Cdn.cdn_repos_for_errata(errata)

    assert_equal expected_repos.map(&:name).sort, (results + mapped).map(&:name).sort
  end

  test "get cdn repos for zstream errata" do
    errata = @errata[:rhel_6_5_z]
    errata.release.stubs(:is_fasttrack?).returns(false)
    errata.release.stubs(:is_async?).returns(true)

    # link some fast track repos with this variant, then verify they're not
    # included in the result (only primary repos should be included).
    variant = errata.variants.first
    @non_primary_repos.select{ |repo| repo.release_type == 'FastTrackCdnRepo' }.each do |repo|
      CdnRepoLink.create!(:cdn_repo => repo, :variant => variant)
    end

    (results, mapped) = Push::Cdn.cdn_repos_for_errata(errata)
    expected_repos = @expected_rpms_6_5_z.keys.sort

    assert_equal expected_repos, results.map(&:name).sort
  end

  test "get all packages should not return package that is not pushed to cdn" do
    errata = @errata[:rhel_6_3_0]
    rejected_repos = do_not_push_to_cdn(errata)
    actual_repos = Push::Cdn.get_packages_by_errata(errata)

    assert_equal(@expected_repos.reject{|repo, files| rejected_repos.include?(repo)}, actual_repos)
  end

  test "get released packages should return empty list if errata not support cdn" do
    errata = @errata[:rhel_6_3_0]
    errata.expects(:supports_cdn_stage?).once.returns(false)
    errata.expects(:supports_cdn_live?).once.returns(false)
    actual_repos = Push::Cdn.get_released_packages_by_errata(errata)

    assert_equal({}, actual_repos)
  end

  test "get released packages should not return package that is not pushed to cdn" do
    errata = @errata[:rhel_6_3_0]

    # ship the packages now
    ship_test_errata_packages(errata)

    rejected_repos = do_not_push_to_cdn(errata)
    expected_repos = @expected_released_repos.reject{|repo, files| rejected_repos.include?(repo)}
    actual_repos = Push::Cdn.get_released_packages_by_errata(errata)

    assert_equal(expected_repos, actual_repos)
  end

  test "get released packages returns correct packages for adjacent stream" do
    # assume we never ship this package before, so all errata should have empty released packages list in the beginning
    @errata.each_pair do |k,erratum|
      assert_equal({}, Push::Cdn.get_released_packages_by_errata(erratum))
    end

    rhel_6_3_0 = @errata[:rhel_6_3_0]
    rhel_6_5_z = @errata[:rhel_6_5_z]

    rhel_6_3_0_krb5_1_0_repos = get_expected_outputs(@expected_rpms_6, "1.0.1", "1.el6")
    rhel_6_5_z_krb5_1_0_repos = get_expected_outputs(@expected_rpms_6_server_base, "1.0.1", "1.el6")

    # now we ship RHEL 6.3 main stream erratum
    ship_test_errata_packages(rhel_6_3_0)

    # check if the RHEL 6.3 erratum reports the correct released packages
    assert_cdn_repos_match(rhel_6_3_0_krb5_1_0_repos, Push::Cdn.get_released_packages_by_errata(rhel_6_3_0))

    # z-stream errata should also report the main stream packages as the latest
    assert_cdn_repos_match(rhel_6_5_z_krb5_1_0_repos, Push::Cdn.get_released_packages_by_errata(rhel_6_5_z))

    # now we ship RHEL 6.5.z  z-stream erratum
    ship_test_errata_packages(rhel_6_5_z)

    rhel_6_3_0_krb5_2_0_repos = get_expected_outputs(@expected_rpms_6_server, "2.0.1", "1.el6_5.1")
    rhel_6_5_z_krb5_2_0_repos = get_expected_outputs(@expected_rpms_6_5_z, "2.0.1", "1.el6_5.1")


    # main stream errata should now report main stream overlapped by z-stream
    # packages as the latest
    assert_cdn_repos_match(rhel_6_3_0_krb5_1_0_repos.merge(rhel_6_3_0_krb5_2_0_repos),
                           Push::Cdn.get_released_packages_by_errata(rhel_6_3_0))

    # check if the RHEL 6.5.z z-stream erratum reports the correct released packages
    assert_cdn_repos_match(rhel_6_5_z_krb5_2_0_repos, Push::Cdn.get_released_packages_by_errata(rhel_6_5_z))
  end

  test "get_released_packages returns correct packages for layered product" do
    RHBA.any_instance.expects(:supports_cdn_live?).at_least_once.returns(true)
    Package.any_instance.stubs(:supports_cdn?).returns(true)

    # simulate the case in errata_id 13713
    rhn_tool_6_2_z = ProductVersion.find_by_name("RHEL-6-RHNTOOLS-6.2.Z")
    cobbler_2_0_7 = BrewBuild.find_by_nvr("cobbler-2.0.7-21.el6sat")

    rhba = create_test_rhba("RHN Tools", "cobbler-2.0.7-21.el6sat")

    # add additional mapping
    ErrataBrewMapping.create!(:product_version => rhn_tool_6_2_z,
                              :errata => rhba,
                              :brew_build => cobbler_2_0_7,
                              :package => cobbler_2_0_7.package)
    rhba.reload

    # return nothing because no packages were released previously
    assert_equal({}, Push::Cdn.get_released_packages_by_errata(rhba))

    # fake released packages in base channel
    rhel_6 = ProductVersion.find_by_name("RHEL-6")
    v6_server = Variant.find_by_name("6Server")
    arch = Arch.find_by_name("x86_64")
    cobbler_2_0_7.brew_rpms.each do |rpm|
      ReleasedPackage.create!(
        :variant => v6_server,
        :product_version => rhel_6,
        :arch => arch,
        :package => rpm.package,
        :brew_build => rpm.brew_build,
        :brew_rpm => rpm,
        :full_path => rpm.file_path,
        :errata => nil)
    end

    # The result should contain 'cobbler' which already shipped to the base cdn repo
    assert_equal @rhn_tools_rpms, Push::Cdn.get_released_packages_by_errata(rhba)
  end
end

class CdnMultiProductGetPackagesTest < ActiveSupport::TestCase
  setup do
    @product_version = ProductVersion.find_by_name('RHEL-6')
  end

  MULTI_PRODUCT_ADVISORY_ID = 13147
  MULTI_PRODUCT_REPOS_DISABLED = %w[
    rhel-6-server-optional-rpms__6Server__i386
    rhel-6-server-optional-rpms__6Server__ppc64
    rhel-6-server-optional-rpms__6Server__x390x
    rhel-6-server-optional-rpms__6Server__x86_64
    rhel-6-server-rpms__6Server__i386
    rhel-6-server-rpms__6Server__ppc64
    rhel-6-server-rpms__6Server__s390x
    rhel-6-server-rpms__6Server__x86_64
    rhel-6-server-source-rpms__6Server__x86_64
  ]

  MULTI_PRODUCT_REPOS_ENABLED = %w[rhel-6-rhev-s-rpms__6Server-RHEV-S__x86_64] + MULTI_PRODUCT_REPOS_DISABLED
  MULTI_PRODUCT_RPMS = %w[
    /mnt/redhat/brewroot/packages/sblim-cim-client2/2.1.3/2.el6/data/signed/fd431d51/noarch/sblim-cim-client2-2.1.3-2.el6.noarch.rpm
    /mnt/redhat/brewroot/packages/sblim-cim-client2/2.1.3/2.el6/data/signed/fd431d51/noarch/sblim-cim-client2-javadoc-2.1.3-2.el6.noarch.rpm
    /mnt/redhat/brewroot/packages/sblim-cim-client2/2.1.3/2.el6/data/signed/fd431d51/noarch/sblim-cim-client2-manual-2.1.3-2.el6.noarch.rpm
    /mnt/redhat/brewroot/packages/sblim-cim-client2/2.1.3/2.el6/data/signed/fd431d51/src/sblim-cim-client2-2.1.3-2.el6.src.rpm
  ]

  def multi_product_get_packages_test(method, attrs, &block)
    errata = Errata.find(MULTI_PRODUCT_ADVISORY_ID)
    map = MultiProductCdnRepoMap.first

    assert errata.product_versions.any?{|pv| pv.cdn_repos.include?(map.origin)},
      'fixture problem: test advisory is missing mapped cdn repo'

    errata.update_attributes(attrs)

    packages = Push::Cdn.send(method, errata)
    repos = packages.map(&:first).sort
    rpms = packages.map(&:second).map(&:to_a).flatten.uniq.sort
    yield(repos, rpms)
  end

  test "get_packages doesn't follow cdn repo map if multi products disabled" do
    multi_product_get_packages_test(:get_packages_by_errata, {:supports_multiple_product_destinations => false}) do |actual_repos, actual_rpms|
      assert_array_equal MULTI_PRODUCT_REPOS_DISABLED, actual_repos
      assert_array_equal MULTI_PRODUCT_RPMS, actual_rpms
    end
  end

  test "get_packages follows cdn repo map if multi products enabled" do
    multi_product_get_packages_test(:get_packages_by_errata, {:supports_multiple_product_destinations => true}) do |actual_repos, actual_rpms|
      assert_array_equal MULTI_PRODUCT_REPOS_ENABLED, actual_repos
      assert_array_equal MULTI_PRODUCT_RPMS, actual_rpms
    end
  end

  test "get_released_packages doesn't follow cdn repo map if multi products disabled" do
    multi_product_get_packages_test(:get_released_packages_by_errata, {:supports_multiple_product_destinations => false}) do |actual_repos, actual_rpms|
      assert_array_equal MULTI_PRODUCT_REPOS_DISABLED, actual_repos
    end
  end

  test "get_released_packages follows cdn repo map if multi products enabled" do
    multi_product_get_packages_test(:get_released_packages_by_errata, {:supports_multiple_product_destinations => true}) do |actual_repos, actual_rpms|
      assert_array_equal MULTI_PRODUCT_REPOS_ENABLED, actual_repos
    end
  end
end
