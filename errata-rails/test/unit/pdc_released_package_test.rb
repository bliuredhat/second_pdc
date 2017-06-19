require 'test_helper'

class PdcReleasedPackageTest < ActiveSupport::TestCase
  setup do
    @pdc_errata = Errata.find(21132)
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

    @pdc_release = PdcRelease.get('ceph-2.1-updates@rhel-7')
    @pdc_variant = PdcVariant.get_by_release_and_variant('ceph-2.1-updates@rhel-7', 'MON')
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
    return PdcReleasedPackage.create!(
      :brew_build => build,
      :package => build.package,
      :brew_rpm => rpm,
      :pdc_variant => @pdc_variant,
      :pdc_release => @pdc_release,
      :arch => rpm.arch,
      :full_path => "/mnt/redhat/brewroot/packages/#{rpm.rpm_name}")
  end

  def change_errata_states_from_shipped_to_just_before(user)
    # Prevent "packages are not signed" validation error when changing state
    @pdc_errata.brew_builds.each{ |b| b.mark_as_signed(SigKey.default_key) }

    [State::REL_PREP, State::PUSH_READY, State::IN_PUSH].each do |state|
      @pdc_errata.change_state!(state, user)
    end
  end

  test 'for errata includes pdc release from mappings and repos/channels' do
    VCR.use_cassette 'pdc_released_package_test_errata_includes_pdc_release' do
      result = PdcReleasedPackage.make_released_packages_for_errata(@pdc_errata)
      assert result.count > 0
      package_name = @pdc_errata.pdc_errata_release_builds.first.package.name
      result.each do |pdc_released_package|
        assert pdc_released_package.is_a? PdcReleasedPackage
        assert_equal @pdc_errata.pdc_releases.first, pdc_released_package.pdc_release
        assert_equal pdc_released_package.current, 1
        assert_match(
          /#{Regexp.escape('/mnt/redhat/brewroot/packages/python-crypto/2.6.1/1.2.el7cp')}.*#{package_name}.*\.rpm/,
          pdc_released_package.full_path)
      end
      assert @pdc_errata.build_mappings.all?(&:shipped)
    end
  end

  test 'make released packages for errata should be triggered after errata shipped' do
    user = User.default_qa_user
    change_errata_states_from_shipped_to_just_before(user)
    PdcReleasedPackage.expects(:make_released_packages_for_errata).with(@pdc_errata)
    force_sync_delayed_jobs /PerformableMethod/ do
      @pdc_errata.change_state!(State::SHIPPED_LIVE, user)
    end
  end

  test 'released package audit must have released package or pdc released package info' do
    error = assert_raise(ActiveRecord::RecordInvalid) do
      ReleasedPackageAudit.create!(:released_package_update => ReleasedPackageUpdate.first)
    end
    assert_equal "Validation failed: Released package and pdc released package can't be both null", error.message
  end

  test 'released package audit must not have released package and pdc released package info both' do
    error = assert_raise(ActiveRecord::RecordInvalid) do
      ReleasedPackageAudit.create!(:released_package_update => ReleasedPackageUpdate.first,
                                   :released_package => ReleasedPackage.first,
                                   :pdc_released_package => PdcReleasedPackage.first)
    end
    assert_equal "Validation failed: Released package and pdc released package can't both be set", error.message
  end

  test "get latest released rpms for build" do
    expected_result = [
      "TestPackage-2.0-1.el6.x86_64.rpm",
      "TestPackage-debuginfo-2.0-1.el6.x86_64.rpm",
      "TestPackage2-2.0-1.el6.x86_64.rpm"]

    build = BrewBuild.find_by_nvr('TestPackage-3.0-1.el6')
    result = PdcReleasedPackage.last_released_packages_by_variant_and_arch(@pdc_variant, @x86_arch, build.brew_rpms)
    rpm_names = result[:list].map{|r| r.brew_rpm.rpm_name}
    errors = result[:error_messages]

    assert_equal expected_result.sort, rpm_names.sort
    assert errors.empty?
  end

  test "get latest released rpms for build with version validation" do
    VCR.use_cassette 'pdc_released_package_test_released_rpms' do
      expected_result = [
        "TestPackage-2.0-1.el6.x86_64.rpm",
        "TestPackage-debuginfo-2.0-1.el6.x86_64.rpm"]

      build = BrewBuild.find_by_nvr('TestPackage-3.0-1.el6')
      result = PdcReleasedPackage.last_released_packages_by_variant_and_arch(@pdc_variant, @x86_arch, build.brew_rpms,
                                                                             {:validate_version => true})
      rpm_names = result[:list].map{|r| r.brew_rpm.rpm_name}
      errors = result[:error_messages]

      assert_equal expected_result.sort, rpm_names.sort
      assert !errors.empty?
      assert_match(/Build 'TestPackage2-2.0-1.el6' has newer or equal version of 'TestPackage2-1.0-1.el6.x86_64.rpm' in '#{@pdc_variant.name}' variant/, errors[0])
    end
  end

  test "can not create pdc errata release build with old version" do
    VCR.insert_cassette fixture_name
    error = assert_raise(ActiveRecord::RecordInvalid) do
      PdcErrataReleaseBuild.create!(:pdc_errata_release => PdcErrataRelease.find(4),
                                    :brew_build => BrewBuild.find_by_nvr('TestPackage-2.0-1.el6'))
    end
    error_message = """Validation failed: Brew build Unable to add build 'TestPackage-2.0-1.el6'.,

                       Brew build Build 'TestPackage-2.0-1.el6' has newer or equal version of
                       'TestPackage-2.0-1.el6.src.rpm' in 'MON' variant.,
                       Brew build Build 'TestPackage-2.0-1.el6' has newer or equal version of
                       'TestPackage-2.0-1.el6.x86_64.rpm' in 'MON' variant.,
                       Brew build Build 'TestPackage-2.0-1.el6' has newer or equal version of
                       'TestPackage-2.0-1.el6.ppc64.rpm' in 'MON' variant.,
                       Brew build Build 'TestPackage-2.0-1.el6' has newer or equal version of
                       'TestPackage-debuginfo-2.0-1.el6.x86_64.rpm' in 'MON' variant.,
                       Brew build Build 'TestPackage-2.0-1.el6' has newer or
                       equal version of 'TestPackage-debuginfo-2.0-1.el6.ppc64.rpm' in 'MON' variant."""

    assert_equal error_message.squish, error.message.squish
    VCR.eject_cassette
  end
end
