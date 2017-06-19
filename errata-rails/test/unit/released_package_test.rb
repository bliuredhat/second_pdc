require 'test_helper'

class ReleasedPackageTest < ActiveSupport::TestCase
  setup do
    # Codes below should generate the following test data:
    # Package: TestPackage
    #   BrewBuild: TestPackage-1.0-1.el6 (Released)
    #     BrewRpm: TestPackage-1.0-1.el6.src.rpm
    #     BrewRpm: TestPackage-1.0-1.el6.x86_64.rpm
    #     BrewRpm: TestPackage-1.0-1.el6.ppc64.rpm
    #     BrewRpm: TestPackage-debuginfo-1.0-1.el6.x86_64.rpm
    #     BrewRpm: TestPackage-debuginfo-1.0-1.el6.ppc64.rpm
    #   BrewBuild: TestPackage-2.0-1.el6 (Released)
    #     BrewRpm: TestPackage-2.0-1.el6.src.rpm
    #     BrewRpm: TestPackage-2.0-1.el6.x86_64.rpm
    #     BrewRpm: TestPackage-2.0-1.el6.ppc64.rpm
    #     BrewRpm: TestPackage-debuginfo-2.0-1.el6.x86_64.rpm
    #     BrewRpm: TestPackage-debuginfo-2.0-1.el6.ppc64.rpm
    #   BrewBuild: TestPackage-3.0-1.el6 (Unreleased)
    #     BrewRpm: TestPackage-3.0-1.el6.src.rpm
    #     BrewRpm: TestPackage-3.0-1.el6.x86_64.rpm
    #     BrewRpm: TestPackage-3.0-1.el6.ppc64.rpm
    #     BrewRpm: TestPackage-debuginfo-3.0-1.el6.x86_64.rpm
    #     BrewRpm: TestPackage-debuginfo-3.0-1.el6.ppc64.rpm
    #     BrewRpm: TestPackage2-1.0-1.el6.x86_64.rpm
    #     BrewRpm: TestPackage2-1.0-1.el6.ppc64.rpm
    # Package: TestPackage2
    #   BrewBuild: TestPackage2-2.0-1.el6 (Released)
    #     BrewRpm: TestPackage2-2.0-1.el6.src.rpm
    #     BrewRpm: TestPackage2-2.0-1.el6.x86_64.rpm
    #     BrewRpm: TestPackage2-2.0-1.el6.ppc64.rpm
    #     BrewRpm: TestPackage2-debuginfo-2.0-1.el6.x86_64.rpm
    #     BrewRpm: TestPackage2-debuginfo-2.0-1.el6.ppc64.rpm

    @product_version = ProductVersion.find_by_name('RHEL-6')
    @variant = Variant.find_by_name('6Server')
    @x86_arch = Arch.find_by_name('x86_64')
    list = [
      ['TestPackage-1.0-1.el6', true],
      ['TestPackage-2.0-1.el6', true],
      ['TestPackage-3.0-1.el6', false],
      ['TestPackage2-2.0-1.el6', true],
    ]

    list.each do |params|
      prepare_test_data(*params)
    end

    # Add an older version of TestPackage2 to the latest TestPackage
    ['x86_64', 'ppc64'].each do |arch_name|
      build = BrewBuild.find_by_nvr('TestPackage-3.0-1.el6')
      rpm = create_brew_rpm(build, "TestPackage2-1.0-1.el6", arch_name)
      create_released_rpm(build, rpm)
    end
  end

  def prepare_test_data(nvr, released, arches = ['x86_64', 'ppc64'])
    nvr_matches = nvr.match("^(.*)-([^-]+)-([^-]+)$")
    assert !nvr_matches.nil?

    n = nvr_matches[1]
    v = nvr_matches[2]
    r = nvr_matches[3]

    package = Package.find_by_name(n)
    if !package
      package = Package.create!(:name => n)
    end

    build = BrewBuild.create!(
      :package => package,
      :version => v,
      :release => r,
      :nvr => nvr)

    # Create srpm
    srpm = create_brew_rpm(build, nvr, 'SRPMS')
    create_released_rpm(build, srpm) if released

    # Create brew rpms and released rpms data
    ["", "-debuginfo"].each do |type|
      arches.each do |arch_name|
        rpm = create_brew_rpm(build, "#{n}#{type}-#{v}-#{r}", arch_name)
        create_released_rpm(build, rpm) if released
      end
    end
  end

  def create_brew_rpm(build, nvr, arch_name)
    arch = Arch.find_by_name(arch_name)
    return BrewRpm.create!(
      :id_brew => BrewRpm.pluck('max(id_brew)').first + 100,
      :brew_build => build,
      :package => build.package,
      :name => nvr,
      :arch => arch)
  end

  def create_released_rpm(build, rpm)
    return ReleasedPackage.create!(
      :brew_build => build,
      :package => build.package,
      :brew_rpm => rpm,
      :product_version => @product_version,
      :version_id => @variant.id,
      :arch => rpm.arch,
      :full_path => "/mnt/redhat/brewroot/packages/#{rpm.rpm_name}")
  end

  test "get all released rpms for build" do
    expected_result = [
      "TestPackage-2.0-1.el6.src.rpm",
      "TestPackage-2.0-1.el6.x86_64.rpm",
      "TestPackage-2.0-1.el6.ppc64.rpm",
      "TestPackage-debuginfo-2.0-1.el6.x86_64.rpm",
      "TestPackage-debuginfo-2.0-1.el6.ppc64.rpm",
      "TestPackage2-2.0-1.el6.src.rpm",
      "TestPackage2-2.0-1.el6.x86_64.rpm",
      "TestPackage2-2.0-1.el6.ppc64.rpm"]

    build = BrewBuild.find_by_nvr('TestPackage-3.0-1.el6')
    rpm_names = ReleasedPackage.for_brew_rpms(build.brew_rpms).values.flatten.map{|r| r.brew_rpm.rpm_name }
    assert_equal expected_result.sort, rpm_names.sort
  end

  test 'for_brew_rpms returns nothing if passed no rpms' do
    rpms = BrewRpm.where('0 = 1')

    # Also verify that it doesn't actually hit the DB in this case.
    ReleasedPackage.expects(:connection).never

    rp = ReleasedPackage.for_brew_rpms(rpms)
    assert rp.empty?
  end

  test "get latest released rpms for build" do
    expected_result = [
      "TestPackage-2.0-1.el6.x86_64.rpm",
      "TestPackage-debuginfo-2.0-1.el6.x86_64.rpm",
      "TestPackage2-2.0-1.el6.x86_64.rpm"]

    build = BrewBuild.find_by_nvr('TestPackage-3.0-1.el6')
    result = ReleasedPackage.last_released_packages_by_variant_and_arch(@variant, @x86_arch, build.brew_rpms)
    rpm_names = result[:list].map{|r| r.brew_rpm.rpm_name}
    errors = result[:error_messages]

    assert_equal expected_result.sort, rpm_names.sort
    assert errors.empty?
  end

  test "get latest released rpms for build with version validation" do
    expected_result = [
      "TestPackage-2.0-1.el6.x86_64.rpm",
      "TestPackage-debuginfo-2.0-1.el6.x86_64.rpm"]

    build = BrewBuild.find_by_nvr('TestPackage-3.0-1.el6')
    result = ReleasedPackage.last_released_packages_by_variant_and_arch(@variant, @x86_arch, build.brew_rpms, {:validate_version => true})
    rpm_names = result[:list].map{|r| r.brew_rpm.rpm_name}
    errors = result[:error_messages]

    assert_equal expected_result.sort, rpm_names.sort
    assert !errors.empty?
    assert_match(/Build 'TestPackage2-2.0-1.el6' has newer or equal version of 'TestPackage2-1.0-1.el6.x86_64.rpm' in '#{@variant.name}' variant/, errors[0])
  end

  test "get latest released rpms for kernel build with version validation ignores rpms in kernel-aarch64 builds" do
    variant = Variant.find_by_name('7Server')
    arch = Arch.find_by_name('aarch64')
    brew_build = BrewBuild.find_by_nvr('kernel-3.10.0-327.2.1.el7')
    result = ReleasedPackage.last_released_packages_by_variant_and_arch(variant, arch, brew_build.brew_rpms, {:validate_version => true})
    assert result[:error_messages].empty?, %{#{result[:error_messages].count} errors such as "#{result[:error_messages].first}"}
  end

  # Bug: 1378728
  test 'get released rpms when have both el and ael versions' do
    @product_version = ProductVersion.find_by_name('RHEL-7')
    @variant = Variant.find_by_name('7Server')
    arch = Arch.find_by_name('ppc64le')

    # Simulate packages with el7_1 and ael7b_1 have been released to ppc64le for
    # RHEL-7
    build_list = [
      ['test_package-1.0-1.el7_1',   true,  ['ppc64le']],
      ['test_package-1.0-1.ael7b_1', true,  ['ppc64le']],
      ['test_package-1.0-2.el7',     false, ['ppc64le']],
    ]

    # Create packages, builds. register packages as released
    build_list.each do |params|
      prepare_test_data(*params)
    end
    build = BrewBuild.find_by_nvr('test_package-1.0-2.el7')

    result = ReleasedPackage.
             last_released_packages_by_variant_and_arch(
               @variant,
               arch,
               build.brew_rpms,
               {:validate_version => true})

    assert result[:error_messages].empty?,
           %{#{result[:error_messages].count} errors such as "#{result[:error_messages].first}"}

    expected_list = ["/mnt/redhat/brewroot/packages/test_package-1.0-1.ael7b_1.ppc64le.rpm",
                     "/mnt/redhat/brewroot/packages/test_package-debuginfo-1.0-1.ael7b_1.ppc64le.rpm"]
    assert_array_equal expected_list, result[:list].map(&:full_path)
  end

  test 'like clause ignores redundant names' do
    clause = ReleasedPackage.like_clause_for_rpm_names(%w[
      foo
      foobar
      foo-bar
      baz-quux
      baz
      baq
      ba-ba
      ba-ba-foo-bar-baz
    ])

    words = (clause.downcase.split.uniq - %w[brew_files.name like or]).sort
    assert_equal(
      %w[
        'ba-ba-%'
        'baq-%'
        'baz-%'
        'foo-%'
        'foobar-%'
      ], words
    )
  end
end

class ReleasedPackageCreationTest < ActiveSupport::TestCase

  def released_packages_to_s(rp)
    rp.map{|x| [
        x.product_version.name,
        x.variant.name,
        x.arch.name,
        x.brew_rpm.filename
      ].join(' ')
    }.sort.join("\n")
  end

  def assert_released_packages_for_errata(errata, expected)
    # note: strip_heredoc doesn't strip trailing \n
    expected = expected.strip_heredoc.strip
    count = expected.count("\n") + 1

    assert_difference('ReleasedPackage.count', count) do
      rp = ReleasedPackage.make_released_packages_for_errata(errata)
      actual = released_packages_to_s(rp)
      assert_equal_or_diff(expected, actual)
    end
  end

  def with_hidden_records(klass, &block)
    lambda{ klass.with_scope(:find => {:conditions => '1 = 0'}, &block) }
  end

  def make_released_package_baseline_test(opts = {})
    errata = opts[:errata]
    expected = opts[:expected]

    errata.update_attribute(:supports_multiple_product_destinations, opts[:set_multi_product] || false)

    block = lambda{ assert_released_packages_for_errata(errata, expected) }

    if opts[:hide_multi_product_channel_maps]
      block = with_hidden_records(MultiProductChannelMap, &block)
    end
    if opts[:hide_multi_product_cdn_repo_maps]
      block = with_hidden_records(MultiProductCdnRepoMap, &block)
    end

    block.call()
  end

  # The below tests check which ReleasedPackages are created for an advisory
  # with various different multi-product mapping settings.
  # They're based on comparisons against the following baseline, which lists
  # every product version, variant, arch and RPM expected to be "released"
  # for the advisory.
  # All the tests are using a multi-product advisory which has multi-product
  # mappings for both RHN and CDN.

  BASELINE = <<-'eos'
RHEL-6 6Server i386 sblim-cim-client2-2.1.3-2.el6.noarch.rpm
RHEL-6 6Server i386 sblim-cim-client2-2.1.3-2.el6.src.rpm
RHEL-6 6Server ppc64 sblim-cim-client2-2.1.3-2.el6.noarch.rpm
RHEL-6 6Server ppc64 sblim-cim-client2-2.1.3-2.el6.src.rpm
RHEL-6 6Server s390x sblim-cim-client2-2.1.3-2.el6.noarch.rpm
RHEL-6 6Server s390x sblim-cim-client2-2.1.3-2.el6.src.rpm
RHEL-6 6Server x86_64 sblim-cim-client2-2.1.3-2.el6.noarch.rpm
RHEL-6 6Server x86_64 sblim-cim-client2-2.1.3-2.el6.src.rpm
RHEL-6 6Server-optional i386 sblim-cim-client2-2.1.3-2.el6.src.rpm
RHEL-6 6Server-optional i386 sblim-cim-client2-javadoc-2.1.3-2.el6.noarch.rpm
RHEL-6 6Server-optional i386 sblim-cim-client2-manual-2.1.3-2.el6.noarch.rpm
RHEL-6 6Server-optional ppc64 sblim-cim-client2-2.1.3-2.el6.src.rpm
RHEL-6 6Server-optional ppc64 sblim-cim-client2-javadoc-2.1.3-2.el6.noarch.rpm
RHEL-6 6Server-optional ppc64 sblim-cim-client2-manual-2.1.3-2.el6.noarch.rpm
RHEL-6 6Server-optional s390x sblim-cim-client2-2.1.3-2.el6.src.rpm
RHEL-6 6Server-optional s390x sblim-cim-client2-javadoc-2.1.3-2.el6.noarch.rpm
RHEL-6 6Server-optional s390x sblim-cim-client2-manual-2.1.3-2.el6.noarch.rpm
RHEL-6 6Server-optional x86_64 sblim-cim-client2-2.1.3-2.el6.src.rpm
RHEL-6 6Server-optional x86_64 sblim-cim-client2-javadoc-2.1.3-2.el6.noarch.rpm
RHEL-6 6Server-optional x86_64 sblim-cim-client2-manual-2.1.3-2.el6.noarch.rpm
RHEL-6 6Workstation i386 sblim-cim-client2-2.1.3-2.el6.noarch.rpm
RHEL-6 6Workstation i386 sblim-cim-client2-2.1.3-2.el6.src.rpm
RHEL-6 6Workstation x86_64 sblim-cim-client2-2.1.3-2.el6.noarch.rpm
RHEL-6 6Workstation x86_64 sblim-cim-client2-2.1.3-2.el6.src.rpm
RHEL-6 6Workstation-optional i386 sblim-cim-client2-2.1.3-2.el6.src.rpm
RHEL-6 6Workstation-optional i386 sblim-cim-client2-javadoc-2.1.3-2.el6.noarch.rpm
RHEL-6 6Workstation-optional i386 sblim-cim-client2-manual-2.1.3-2.el6.noarch.rpm
RHEL-6 6Workstation-optional x86_64 sblim-cim-client2-2.1.3-2.el6.src.rpm
RHEL-6 6Workstation-optional x86_64 sblim-cim-client2-javadoc-2.1.3-2.el6.noarch.rpm
RHEL-6 6Workstation-optional x86_64 sblim-cim-client2-manual-2.1.3-2.el6.noarch.rpm
eos

  test "released package baseline with multi-product and maps" do
    make_released_package_baseline_test(
      :errata => Errata.find(13147),
      :set_multi_product => true,
      :expected => [BASELINE.strip,<<-'eos'].join("\n"))
RHEL-6-RHEV 6Server-RHEV-Hypervisor x86_64 sblim-cim-client2-2.1.3-2.el6.src.rpm
RHEL-6-RHEV 6Server-RHEV-Hypervisor x86_64 sblim-cim-client2-javadoc-2.1.3-2.el6.noarch.rpm
RHEL-6-RHEV 6Server-RHEV-Hypervisor x86_64 sblim-cim-client2-manual-2.1.3-2.el6.noarch.rpm
RHEL-6-RHEV-S 6Server-RHEV-S x86_64 sblim-cim-client2-2.1.3-2.el6.noarch.rpm
eos
  end

  test "released package baseline with deactivated repos" do
    errata = Errata.find(13147)
    pv = ProductVersion.find(149)
    assert_equal [pv], errata.product_versions.to_a, 'fixture problem'

    arches = %w[x86_64 s390x]

    full_baseline = [BASELINE.strip,<<-'eos'.strip_heredoc].join("\n")
      RHEL-6-RHEV 6Server-RHEV-Hypervisor x86_64 sblim-cim-client2-2.1.3-2.el6.src.rpm
      RHEL-6-RHEV 6Server-RHEV-Hypervisor x86_64 sblim-cim-client2-javadoc-2.1.3-2.el6.noarch.rpm
      RHEL-6-RHEV 6Server-RHEV-Hypervisor x86_64 sblim-cim-client2-manual-2.1.3-2.el6.noarch.rpm
      RHEL-6-RHEV-S 6Server-RHEV-S x86_64 sblim-cim-client2-2.1.3-2.el6.noarch.rpm
    eos

    # We're going to disable channels/repos for every arch except "arches".
    # So the generated released packages should only include those arches.
    filtered_baseline = full_baseline.lines.select do |line|
      arches.any?{|arch| line.include?(" #{arch} ")}
    end

    restrict_available_arch(pv, arches)

    make_released_package_baseline_test(
      :errata => errata,
      :set_multi_product => true,
      :expected => filtered_baseline.join)
  end

  # In a given product version, unlink any channels/repos for arches other than
  # arch_names.
  def restrict_available_arch(pv, arch_names)
    condition = {:errata_arches => {:name => arch_names}}
    pv.cdn_repo_links.joins(:cdn_repo => [:arch]).where(condition).tap do |links|
      pv.cdn_repo_links.where('cdn_repo_links.id not in (?)', links).each(&:destroy)
    end

    pv.channel_links.joins(:channel => [:arch]).where(condition).tap do |links|
      pv.channel_links.where('channel_links.id not in (?)', links).each(&:destroy)
    end
  end

  test "released package baseline with multi-product and no maps" do
    make_released_package_baseline_test(
      :errata => Errata.find(13147),
      :set_multi_product => true,
      :hide_multi_product_channel_maps => true,
      :hide_multi_product_cdn_repo_maps => true,
      :expected => BASELINE)
  end

  test "released package baseline with multi-product and only RHN maps" do
    make_released_package_baseline_test(
      :errata => Errata.find(13147),
      :set_multi_product => true,
      :hide_multi_product_cdn_repo_maps => true,
      :expected => [BASELINE.strip,<<-'eos'].join("\n"))
RHEL-6-RHEV 6Server-RHEV-Hypervisor x86_64 sblim-cim-client2-2.1.3-2.el6.src.rpm
RHEL-6-RHEV 6Server-RHEV-Hypervisor x86_64 sblim-cim-client2-javadoc-2.1.3-2.el6.noarch.rpm
RHEL-6-RHEV 6Server-RHEV-Hypervisor x86_64 sblim-cim-client2-manual-2.1.3-2.el6.noarch.rpm
eos
  end

  test "released package baseline with multi-product and only CDN maps" do
    make_released_package_baseline_test(
      :errata => Errata.find(13147),
      :set_multi_product => true,
      :hide_multi_product_channel_maps => true,
      :expected => [BASELINE.strip,<<-'eos'].join("\n"))
RHEL-6-RHEV-S 6Server-RHEV-S x86_64 sblim-cim-client2-2.1.3-2.el6.noarch.rpm
eos
  end

  test "released package baseline with no multi-product" do
    make_released_package_baseline_test(
      :errata => Errata.find(13147),
      :set_multi_product => false,
      :expected => BASELINE)
  end

  test 'for errata includes PV from mappings and repos/channels' do
    # In this advisory, the product versions which the active repos/channels
    # belong to, and the product versions used to add builds to the advisory,
    # differ.
    #
    # This test checks that product versions from both sources end up having
    # released packages recorded against them.
    #
    # The advisory also has some product versions from multi-product mapping
    # rules.
    mapping_pv       = %w[RHEL-6.6.z RHEL-7.0.Z].to_set
    dist_pv          = %w[RHEL-6 RHEL-7].to_set
    multi_product_pv = %w[RHEL-6-OSE-2.0 RHEL-6-OSE-2.1 RHEL-6-OSE-2.2].to_set

    e = Errata.find(19435)

    # Ensure fixture meets expectations
    assert_equal mapping_pv, e.product_versions.map(&:name).to_set
    assert_equal dist_pv, e.
                          active_channels_and_repos_for_available_product_versions.
                          map(&:product_version).map(&:name).to_set


    max_id = ReleasedPackage.pluck('max(id)').first
    ReleasedPackage.make_released_packages_for_errata(e)
    created_rp = ReleasedPackage.where('id > ?', max_id)

    actual_pv = created_rp.map(&:product_version).map(&:name).to_set
    assert_equal mapping_pv + dist_pv + multi_product_pv, actual_pv
  end

  test "add older build to released packages should fail" do
    errata = Errata.find(13147)
    newer_nvr = 'sblim-cim-client2-2.1.3-2.el6'
    older_nvr = 'sblim-cim-client2-2.1.3-1.el6'
    product_version = ProductVersion.find_by_name("RHEL-6")
    # Enable brew_build version check
    opts = { :check_brew_build_version => true, :use_product_listing_cache => true }

    # Add 'sblim-cim-client2-2.1.3-2.el6' newer build to released packages db first
    update = ReleasedPackageUpdate.create!(:reason => 'testing', :user_input => {})
    ReleasedPackage.make_released_packages_for_build(newer_nvr, product_version, update, opts)

    # Now try to add an older build. It should fail
    assert_no_difference('ReleasedPackage.count') do
      error = assert_raises(ActiveRecord::RecordInvalid) do
        ReleasedPackage.make_released_packages_for_build(older_nvr, product_version, update, opts)
      end
      expected = "Validation failed: Brew build '#{older_nvr}' is older than " +
        "the latest released brew build '#{newer_nvr}'."
      assert_equal expected, error.message
    end

    # Disable the brew build check to allow to add older brew build
    opts[:check_brew_build_version] = false
     assert_difference('ReleasedPackage.count', 30) do
       assert_nothing_raised do
         ReleasedPackage.make_released_packages_for_build(older_nvr, product_version, update, opts)
      end
    end
  end

  test "add released package for z-stream pv includes mainline" do
    nvr = 'glibc-2.17-78.el7'
    pv = ProductVersion.find_by_name("RHEL-7.1.Z")

    # Expect the Z-stream and mainline product versions
    expected_pvs = [ pv, ProductVersion.find_by_name('RHEL-7') ]

    check_add_released_packages(nvr, pv, expected_pvs)
  end

  test "add released package for EUS pv excludes mainline" do
    nvr = 'glibc-2.17-78.el7'
    pv = ProductVersion.find_by_name("RHEL-7.1-EUS")

    # Expect just the one product version to be updated
    expected_pvs = [ pv ]

    check_add_released_packages(nvr, pv, expected_pvs)
  end

  def check_add_released_packages(nvr, pv, expected_pvs)
    update = mock
    update.expects(:add_released_packages).once.with { |*rp|
      updated_product_versions = rp.first.map(&:product_version).uniq.sort
      assert_equal expected_pvs.sort, updated_product_versions
      true
    }

    # Enable brew_build version check
    opts = { :check_brew_build_version => true, :use_product_listing_cache => true }

    ReleasedPackage.make_released_packages_for_build(nvr, pv, update, opts)
  end

  test "for docker advisory, make_released_packages updates released_errata in brew builds" do
    e = Errata.find(21100)
    assert e.has_docker?
    e.status = 'SHIPPED_LIVE'
    rp = ReleasedPackage.make_released_packages_for_errata(e)

    # No ReleasedPackages are created for Docker yet
    assert rp.empty?

    # But the builds have released_errata updated
    e.brew_builds.each { |build| assert_equal e, build.released_errata }
  end

  # Previously make_released_packages_for_build/errata obsoleted released
  # packages that matched product_version and package. This would cause even
  # removing those packages that were not included in the listings for the
  # newer build.
  # Now it only obsoletes the packages belonging to the new listings.
  # Bug: 1376282
  test 'obsolete released packages referring to product listings' do
    errata = Errata.find(13147)
    old_build = BrewBuild.find_by_nvr('sblim-cim-client2-2.1.3-1.el6')
    new_build = BrewBuild.find_by_nvr('sblim-cim-client2-2.1.3-2.el6')
    rhel6 = ProductVersion.find_by_name("RHEL-6")
    first_arch_listings =  {'src' => ['x86_64', 'i386', 'ppc64', 's390x'],
                            'noarch'=> ['x86_64', 'i386', 'ppc64', 's390x']}
    # manually remove 2 listings
    second_arch_listings = {'src' => ['x86_64', 'i386', 'ppc64', 's390x'],
                            'noarch'=> ['x86_64', 'i386']}

    ProductListingCache.find_by_product_version_id_and_brew_build_id(rhel6, old_build)
      .update_attributes(
        :cache => {'Server' => {'sblim-cim-client2-2.1.3-1.el6' => first_arch_listings}}.to_yaml)

    ProductListingCache.find_by_product_version_id_and_brew_build_id(rhel6, new_build)
      .update_attributes(
        :cache => {'Server' => {'sblim-cim-client2-2.1.3-2.el6' => second_arch_listings}}.to_yaml)

    # Let's start from the clear database
    ReleasedPackage.where(:product_version_id => rhel6,
                          :package_id => old_build.package).destroy_all

    opts = { :use_product_listing_cache => true }
    update = ReleasedPackageUpdate.create!(:reason => 'testing', :user_input => {})

    # Make released packages for the old build
    # Expected 8 packages are released
    assert_difference('ReleasedPackage.current.count', 8) do
      ReleasedPackage.make_released_packages_for_build(old_build.nvr, rhel6, update, opts)
    end

    # Make released packages for the new build
    # Only matching 6 released packages become obsolete
    query = ReleasedPackage.current.where(:product_version_id => rhel6)
    assert_difference('query.where(:brew_build_id => old_build).count', -6) do
      assert_difference('query.where(:brew_build_id => new_build).count', 6) do
        ReleasedPackage.make_released_packages_for_build(new_build.nvr, rhel6, update, opts)
      end
    end

    # Two released packages with old nvr are still current.
    rps_old_build = query.where(:brew_build_id => old_build,
                                :arch_id => Arch.where(:name => ['ppc64','s390x']))
    assert_equal 2, rps_old_build.count
  end

  test 'obsolete released packages referring to product listings during zstream release' do
    errata = Errata.find(13147)
    old_build = BrewBuild.find_by_nvr('sblim-cim-client2-2.1.3-1.el6')
    new_build = BrewBuild.find_by_nvr('sblim-cim-client2-2.1.3-2.el6')
    rhel6 = ProductVersion.find_by_name("RHEL-6")
    rhel65z = ProductVersion.find_by_name('RHEL-6.5.z')
    first_arch_listings =  {'src' => ['x86_64', 'i386', 'ppc64', 's390x'],
                           'noarch'=> ['x86_64', 'i386', 'ppc64', 's390x']}
    # manually remove 1 listing
    second_arch_listings = {'src' => ['x86_64', 'i386', 'ppc64', 's390x'],
                            'noarch'=> ['x86_64', 'i386', 'ppc64']}
    # manually remove 2 listings
    third_arch_listings =  {'src' => ['x86_64', 'i386', 'ppc64', 's390x'],
                           'noarch'=> ['x86_64', 'i386']}

    ProductListingCache.find_by_product_version_id_and_brew_build_id(rhel6, old_build)
      .update_attributes(
        :cache => {'Server' => {'sblim-cim-client2-2.1.3-1.el6' => first_arch_listings}}.to_yaml)

    ProductListingCache.find_by_product_version_id_and_brew_build_id(rhel6, new_build)
      .update_attributes(
        :cache => {'Server' => {'sblim-cim-client2-2.1.3-2.el6' => second_arch_listings}}.to_yaml)

    ProductListingCache.create!(
      :product_version => rhel65z,
      :brew_build => new_build,
      :cache => {'Server' => {'sblim-cim-client2-2.1.3-2.el6' => third_arch_listings}}.to_yaml)

    # Let's start from the clear database
    ReleasedPackage.where(:product_version_id => [rhel6, rhel65z],
                          :package_id => old_build.package).destroy_all

    opts = { :use_product_listing_cache => true }
    update = ReleasedPackageUpdate.create!(:reason => 'testing', :user_input => {})

    # Make released packages for the old build
    # Expected 8 packages are released
    assert_difference('ReleasedPackage.current.count', 8) do
      ReleasedPackage.make_released_packages_for_build(old_build.nvr, rhel6, update, opts)
    end

    cur_rhel6_old = ReleasedPackage.current.where(:product_version_id => rhel6, :brew_build_id => old_build)
    cur_rhel6_new = ReleasedPackage.current.where(:product_version_id => rhel6, :brew_build_id => new_build)
    cur_rhel65z_new = ReleasedPackage.current.where(:product_version_id => rhel65z, :brew_build_id => new_build)

    # Make released packages for the new build
    assert_difference('cur_rhel6_old.count', -7) do
      assert_difference('cur_rhel6_new.count', 7) do
        assert_difference('cur_rhel65z_new.count', 6) do
          ReleasedPackage.make_released_packages_for_build(new_build.nvr, rhel65z, update, opts)
        end
      end
    end

    # One released package with old nvr is still current
    assert_equal 1, cur_rhel6_old.count
    # It has that arch which was manually removed
    assert_equal 's390x', cur_rhel6_old.first.arch.name
  end
end
