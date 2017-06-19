require 'test_helper'

class PushRhnLibTest < ActiveSupport::TestCase
  setup do
    @expected_rpms_6_3_0_base = [
      [ "rhel-x86_64-server-optional-6"      , %w{ javadoc_noarch_rpm manual_noarch_rpm src_rpm } ],
      [ "rhel-i386-workstation-optional-6"   , %w{ javadoc_noarch_rpm manual_noarch_rpm src_rpm } ],
      [ "rhel-s390x-server-optional-6"       , %w{ javadoc_noarch_rpm manual_noarch_rpm src_rpm } ],
      [ "rhel-x86_64-workstation-optional-6" , %w{ javadoc_noarch_rpm manual_noarch_rpm src_rpm } ],
      [ "rhel-i386-server-optional-6"        , %w{ javadoc_noarch_rpm manual_noarch_rpm src_rpm } ],
      [ "rhel-ppc64-server-optional-6"       , %w{ javadoc_noarch_rpm manual_noarch_rpm src_rpm } ],
      [ "rhel-i386-workstation-6"            , %w{ noarch_rpm src_rpm } ],
      [ "rhel-x86_64-workstation-6"          , %w{ noarch_rpm src_rpm } ],
      [ "rhel-ppc64-server-6"                , %w{ noarch_rpm src_rpm } ],
      [ "rhel-s390x-server-6"                , %w{ noarch_rpm src_rpm } ],
      [ "rhel-x86_64-server-6"               , %w{ noarch_rpm src_rpm } ],
      [ "rhel-i386-server-6"                 , %w{ noarch_rpm src_rpm } ],
    ]

    @expected_rpms_fast = [
      [ "rhel-x86_64-server-optional-fastrack-6"      , %w{ javadoc_noarch_rpm manual_noarch_rpm src_rpm } ],
      [ "rhel-i386-workstation-optional-fastrack-6"   , %w{ javadoc_noarch_rpm manual_noarch_rpm src_rpm } ],
      [ "rhel-s390x-server-optional-fastrack-6"       , %w{ javadoc_noarch_rpm manual_noarch_rpm src_rpm } ],
      [ "rhel-x86_64-workstation-optional-fastrack-6" , %w{ javadoc_noarch_rpm manual_noarch_rpm src_rpm } ],
      [ "rhel-i386-server-optional-fastrack-6"        , %w{ javadoc_noarch_rpm manual_noarch_rpm src_rpm } ],
      [ "rhel-ppc64-server-optional-fastrack-6"       , %w{ javadoc_noarch_rpm manual_noarch_rpm src_rpm } ],
      [ "rhel-i386-workstation-fastrack-6"            , %w{ noarch_rpm src_rpm } ],
      [ "rhel-x86_64-workstation-fastrack-6"          , %w{ noarch_rpm src_rpm } ],
      [ "rhel-ppc64-server-fastrack-6"                , %w{ noarch_rpm src_rpm } ],
      [ "rhel-s390x-server-fastrack-6"                , %w{ noarch_rpm src_rpm } ],
      [ "rhel-x86_64-server-fastrack-6"               , %w{ noarch_rpm src_rpm } ],
      [ "rhel-i386-server-fastrack-6"                 , %w{ noarch_rpm src_rpm } ],
    ]

    @expected_rpms_6_3_0 = @expected_rpms_6_3_0_base + @expected_rpms_fast

    @expected_rpms_6_3_z = [
      [ "rhel-x86_64-server-6.3.z"          , %w{ noarch_rpm src_rpm } ],
      [ "rhel-x86_64-server-optional-6.3.z" , %w{ javadoc_noarch_rpm manual_noarch_rpm src_rpm } ],
      [ "rhel-ppc64-server-6.3.z"           , %w{ noarch_rpm src_rpm }],
      [ "rhel-ppc64-server-optional-6.3.z"  , %w{ javadoc_noarch_rpm manual_noarch_rpm src_rpm } ],
      [ "rhel-s390x-server-6.3.z"           , %w{ noarch_rpm src_rpm }],
      [ "rhel-s390x-server-optional-6.3.z"  , %w{ javadoc_noarch_rpm manual_noarch_rpm src_rpm } ],
      [ "rhel-i386-server-6.3.z"            , %w{ noarch_rpm src_rpm }],
      [ "rhel-i386-server-optional-6.3.z"   , %w{ javadoc_noarch_rpm manual_noarch_rpm src_rpm } ],
    ] + @expected_rpms_6_3_0_base

    @expected_multi_product_rpms = [
      ["rhel-x86_64-server-6-rhevh", %w{ javadoc_noarch_rpm manual_noarch_rpm src_rpm } ],
    ]

    cobbler_path    = "/mnt/redhat/brewroot/packages/cobbler/2.0.7/21.el6sat/data/signed/fd431d51"
    koan_rpm        = "#{cobbler_path}/noarch/koan-2.0.7-21.el6sat.noarch.rpm"
    cobbler_src_rpm = "#{cobbler_path}/src/cobbler-2.0.7-21.el6sat.src.rpm"
    cobbler_rpm     = "#{cobbler_path}/noarch/cobbler-2.0.7-21.el6sat.noarch.rpm"

    @rhn_tools_rpms = {
      "rhn-tools-rhel-x86_64-server-6" => [koan_rpm, cobbler_src_rpm, cobbler_rpm].to_set,
    }

    @expected_rpms_6_3_0_multi = @expected_rpms_6_3_0 + @expected_multi_product_rpms

    @expected_6_3_0_files       = get_expected_outputs(@expected_rpms_6_3_0, "1.0.1", "1.el6")
    @expected_6_3_0_base_files  = get_expected_outputs(@expected_rpms_6_3_0_base, "1.0.1", "1.el6")
    @expected_6_3_0_files_multi = get_expected_outputs(@expected_rpms_6_3_0_multi, "1.0.1", "1.el6")

    # clean up any released rpms for this package before testing
    package = Package.find_by_name("sblim-cim-client2")
    ReleasedPackage.where(:package_id => package).delete_all

    # create test errata (1 main-stream and 1 z-stream)
    @errata = {}
    product_listing_id = 38136
    {
     :rhel_6_3_0 => {:rhel => "RHEL-6.3.0", :rpm_ver => "1.0.1", :rpm_rel => "1.el6",     :product_version => "RHEL-6"},
     :rhel_6_3_z => {:rhel => "RHEL-6.3.z", :rpm_ver => "2.0.1", :rpm_rel => "1.el6_3.1", :product_version => "RHEL-6.3.z"},
    }.each_pair do |k,v|
      @errata[k] = create_test_errata(v[:rhel], v[:rpm_ver], v[:rpm_rel], product_listing_id, v[:product_version])
    end

    # Use cached product listings only
    ProductListing.stubs(:get_brew_product_listings => {})
  end

  def get_expected_outputs(template, rpm_version, rpm_release)
    path = "/mnt/redhat/brewroot/packages/sblim-cim-client2/#{rpm_version}/#{rpm_release}"
    file_list = {
      :noarch_rpm         => "#{path}/noarch/sblim-cim-client2-#{rpm_version}-#{rpm_release}.noarch.rpm",
      :src_rpm            => "#{path}/src/sblim-cim-client2-#{rpm_version}-#{rpm_release}.src.rpm",
      :javadoc_noarch_rpm => "#{path}/noarch/sblim-cim-client2-javadoc-#{rpm_version}-#{rpm_release}.noarch.rpm",
      :manual_noarch_rpm  => "#{path}/noarch/sblim-cim-client2-manual-#{rpm_version}-#{rpm_release}.noarch.rpm",
    }

    return template.each_with_object(Hash.new{|h,k| h[k] = SortedSet.new}) do |(channel, files), h|
      h[channel].merge(files.map{|f| file_list[f.to_sym]})
    end
  end

  def do_not_push_to_rhn(errata)
    package = errata.build_mappings.first.brew_build.package
    variant = Variant.find_by_name('6Server')
    # don't push to rhn
    PackageRestriction.create!(:package => package , :variant => variant, :push_targets => [])
    rejected_channels = variant.channels.map(&:name)
  end

  def create_test_errata(rhel_release, rpm_version, rpm_release, product_listing_id, product_version_name)
    brew_build = create_test_brew_build(product_listing_id, rpm_version, rpm_release, product_version_name)
    rhba = create_test_rhba(rhel_release, brew_build.nvr)
  end

  test "get_packages in a channel" do
    channel = Channel.find_by_name('rhel-x86_64-server-6')
    channel_files = Push::Rhn.get_packages_by_errata(@errata[:rhel_6_3_0], channel)

    assert_equal 1, channel_files.count
    assert_equal @expected_6_3_0_base_files[channel.name], channel_files[channel.name]
  end

  test "get_packages doesn't follow channel map if multi products disabled" do
    channel_files = Push::Rhn.get_packages_by_errata(@errata[:rhel_6_3_0])

    assert_equal @expected_6_3_0_base_files, channel_files
  end

  test "get_packages follows channel map if multi products enabled" do
    Push::Dist.expects(:should_use_multi_product_mapping?).at_least_once.returns(true)
    errata = @errata[:rhel_6_3_0]
    errata.update_attributes(:supports_multiple_product_destinations => true)
    expected_files = get_expected_outputs(@expected_rpms_6_3_0_base + @expected_multi_product_rpms, "1.0.1", "1.el6")
    channel_files = Push::Rhn.get_packages_by_errata(errata)

    assert_equal expected_files, channel_files
  end

  test "get_released_packages in a channel" do
    # ship the advisory
    errata = @errata[:rhel_6_3_0]
    ship_test_errata_packages(errata)
    channel = Channel.find_by_name('rhel-x86_64-server-6')
    channel_files = Push::Rhn.get_released_packages_by_errata(errata, channel)

    assert_equal 1, channel_files.count
    assert_equal @expected_6_3_0_files[channel.name], channel_files[channel.name]
  end

  test "get_released_packages doesn't follow channel map if multi products disabled" do
    # ship the advisory
    errata = @errata[:rhel_6_3_0]
    ship_test_errata_packages(errata)
    channel_files = Push::Rhn.get_released_packages_by_errata(errata)

    assert_equal @expected_6_3_0_files, channel_files
  end

  test "get_released_packages follows channel map if multi products enabled" do
    Push::Dist.expects(:should_use_multi_product_mapping?).at_least_once.returns(true)
    errata = @errata[:rhel_6_3_0]
    errata.update_attributes(:supports_multiple_product_destinations => true)
    # ship the advisory
    ship_test_errata_packages(errata)
    channel_files = Push::Rhn.get_released_packages_by_errata(errata)

    assert_equal @expected_6_3_0_files_multi, channel_files
  end

  test "get_packages should not return package that is not pushed to rhn" do
    # disallow 6Server variant to push to rhn
    errata = @errata[:rhel_6_3_0]
    rejected_channels = do_not_push_to_rhn(errata)
    channel_files = Push::Rhn.get_packages_by_errata(errata)

    assert_equal(
      @expected_6_3_0_base_files.reject{|channel, files| rejected_channels.include?(channel)},
      channel_files
    )
  end

  test "get_released_packages should return empty list if errata not support rhn" do
    # ship the advisory
    errata = @errata[:rhel_6_3_0]
    ship_test_errata_packages(errata)
    errata.expects(:supports_rhn_stage?).once.returns(false)
    errata.expects(:supports_rhn_live?).once.returns(false)
    channel_files = Push::Rhn.get_released_packages_by_errata(errata)

    assert_equal({}, channel_files)
  end

  test "get_released_packages should not return package that is not pushed to rhn" do
    # disallow 6Server variant to push to rhn
    errata = @errata[:rhel_6_3_0]
    rejected_channels = do_not_push_to_rhn(errata)
    # ship the advisory
    ship_test_errata_packages(errata)
    channel_files = Push::Rhn.get_released_packages_by_errata(errata)

    assert_equal(
      @expected_6_3_0_files.reject{|channel, files| rejected_channels.include?(channel)},
      channel_files
    )
  end

  test "get_released_packages returns correct packages for adjacent stream" do
    # assume we never ship this package before, so all errata should have empty released packages list in the beginning
    @errata.each_pair do |k,erratum|
      assert_equal({}, Push::Rhn.get_released_packages_by_errata(erratum))
    end

    # now we ship RHEL 6.3 main stream erratum
    ship_test_errata_packages(@errata[:rhel_6_3_0])

    # check if the RHEL 6.3 erratum reports the correct released packages
    assert_equal @expected_6_3_0_files, Push::Rhn.get_released_packages_by_errata(@errata[:rhel_6_3_0])

    # z-stream errata should also report the main stream packages as the latest
    expected_files = get_expected_outputs(@expected_rpms_6_3_0_base, "1.0.1", "1.el6")
    assert_equal @expected_6_3_0_base_files, Push::Rhn.get_released_packages_by_errata(@errata[:rhel_6_3_z])

    # now we ship RHEL 6.3.z  z-stream erratum
    ship_test_errata_packages(@errata[:rhel_6_3_z])

    # main stream errata should now report the z-stream packages as the latest
    expected_files = get_expected_outputs(@expected_rpms_6_3_0, "2.0.1", "1.el6_3.1")
    assert_equal expected_files, Push::Rhn.get_released_packages_by_errata(@errata[:rhel_6_3_0])

    # check if the RHEL 6.3.z erratum reports the correct released packages
    expected_files = get_expected_outputs(@expected_rpms_6_3_z, "2.0.1", "1.el6_3.1")
    assert_equal expected_files, Push::Rhn.get_released_packages_by_errata(@errata[:rhel_6_3_z])
  end

  test "get_released_packages returns correct packages for layered product" do
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
    assert_equal({}, Push::Rhn.get_released_packages_by_errata(rhba))

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

    # The result should contain 'cobbler' which already shipped to the base channel
    assert_equal @rhn_tools_rpms, Push::Rhn.get_released_packages_by_errata(rhba)
  end
end
