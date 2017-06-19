require 'test_helper'

class PdcErrataTest < ActiveSupport::TestCase

  setup do
    @brew_build = BrewBuild.find_by_nvr('samba-4.1.12-23.el7_1')
    @pdc_release = PdcRelease.get('foo-1')
    @release = Release.find_by_name('PDCTestRelease')
    @product = Product.find_by_name('PDC Test Product')
    @pdc_errata = create_pdc_advisory(@product, @release)
    @pdc_errata.pdc_releases << @pdc_release
  end

  test "creating a pdc errata" do
    assert @pdc_errata
    assert @pdc_errata.is_a?(PdcRHBA)

    assert_equal @product, @pdc_errata.product
    assert_equal @release, @pdc_errata.release
  end

  test "adding a pdc release to a pdc errata" do
    assert_equal [@pdc_release], @pdc_errata.pdc_releases
  end

  test "adding a brew build to a pdc errata" do
    VCR.insert_cassette 'pdc_errata_test_build_to_pdc_errata' do
      @pdc_errata.pdc_errata_releases.first.brew_builds << @brew_build
      assert_equal [@brew_build], @pdc_errata.brew_builds

      # Confirm a few other associations are working okay
      assert_equal @pdc_errata, @pdc_errata.pdc_errata_releases.first.errata
      assert_equal @pdc_errata, @pdc_errata.pdc_errata_releases.first.pdc_errata_release_builds.first.errata
      assert_equal @brew_build, @pdc_errata.pdc_errata_releases.first.pdc_errata_release_builds.first.brew_build
      assert_equal [@brew_build.package], @pdc_errata.packages
    end

  end

  test "brew files and related methods work for a pdc advisory" do
    errata = Errata.find(10000)
    expected = [
      "SRPMS ceph-10.2.3-17.el7cp",
      "aarch64 ceph-base-10.2.3-17.el7cp",
      "x86_64 ceph-10.2.3-17.el7cp",
      "x86_64 ceph-base-10.2.3-17.el7cp",
      "x86_64 ceph-common-10.2.3-17.el7cp" ]

    arch_and_name = ->(f){ "#{f.arch.name} #{f.name}" }
    assert_equal(expected, errata.brew_files.map(&arch_and_name).sort)
    assert_equal(expected, errata.brew_rpms.map(&arch_and_name).sort)

    assert errata.has_rpms?
    refute errata.has_nonrpms?
  end

  test "pdc_maybe class helper" do
    assert_equal PdcRHBA, RHBA.pdc_maybe(true)
    assert_equal RHEA, RHEA.pdc_maybe(false)
    assert_equal RHSA, PdcRHSA.pdc_maybe(false)
    assert_equal PdcRHBA, PdcRHBA.pdc_maybe(true)
  end

  test "can use the create_test_rhba helper to create a PDC advisory" do
   VCR.use_cassettes_for(:pdc_ceph21) do
    nvr = 'ceph-10.2.3-17.el7cp'
    release_name = 'ReleaseForPDC'
    errata = VCR.use_cassette 'pdc_adv_create_test_rhba' do
      create_test_rhba(release_name, nvr)
    end

    assert errata.is_pdc?
    refute errata.bugs.empty?
    assert_equal release_name, errata.release.name
    assert_equal nvr, errata.brew_builds.first.nvr
   end
  end

  test "move pdc advisory to QE with no channels" do
   VCR.use_cassettes_for(:pdc_ceph21) do
    nvr = 'ceph-10.2.3-17.el7cp'
    release_name = 'ReleaseForPDC'
    PdcVariant.any_instance.stubs(:channels).returns([])
    PdcVariant.any_instance.stubs(:cdn_repos).returns([])
    pdc_rhba = VCR.use_cassette 'pdc_adv_create_test_rhba' do
      create_test_rhba(release_name, nvr)
    end
    pass_rpmdiff_runs(pdc_rhba)

    Push::Rhn.expects(:file_channel_map).at_least_once.returns([])
    assert_nothing_raised do
      # Move to QE state with no channels
      pdc_rhba.change_state!('QE', secalert_user, 'moving to QE for test')
    end
    assert pdc_rhba.status_is?(:QE)
   end
  end

  #
  # Helper for creating a PDC advisory
  # (May move this to test_helper later.)
  #
  def create_pdc_advisory(product, release, klass=PdcRHBA)
    klass.create!(
      :reporter => devel_user,
      :synopsis => 'test pdc errata',
      :content => Content.new(
        :topic => 'test',
        :description => 'test',
        :solution => 'fix it'
      ),
      :product => product,
      :release => release
    )
  end

end
