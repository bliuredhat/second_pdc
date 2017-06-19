require 'test_helper'

class PdcErrataReleaseBuildTest < ActiveSupport::TestCase

  setup do
    VCR.insert_cassette fixture_name
  end

  teardown do
    VCR.eject_cassette
  end

  setup do
    @errata = Errata.find(21131)
    @p_e_r_b = @errata.pdc_errata_release_builds.first

    # This will fetch some listings and save them in cache using the VCR file
    PdcProductListing.find_or_fetch(@p_e_r_b.pdc_release, @p_e_r_b.brew_build)
  end

  test "rpm mappings" do
    mapping = @p_e_r_b.cached_product_listings
    assert_instance_of OpenStruct, mapping
    assert_includes mapping.to_h.keys, :MON
  end

  test "fetch product listings from pdc" do
    brew_files = @p_e_r_b.get_file_listing
    assert_equal 6, brew_files.length
  end

  test "invalidate files for pdc build mapping" do
    VCR.use_cassettes_for(:ceph21) do
      build_mapping = PdcErrataReleaseBuild.find(1)
      assert build_mapping.errata_files.current.any?
      assert build_mapping.current?

      build_mapping.obsolete!
      refute build_mapping.errata_files.current.any?
      refute build_mapping.current?
      assert build_mapping.removed_index.present?
    end
  end

  test "make new file listing then obsolete it" do
    VCR.use_cassettes_for(:ceph21) do
      errata = PdcRHBA.find(21131)
      mapping = errata.build_mappings.first

      # TODO: Don't use this magic number here
      expected_count = 6

      # Call make_new_file_listing
      assert_difference('PdcErrataFile.count', expected_count) { mapping.make_new_file_listing }

      # Sanity checks for the newly created PdcErrataFile records
      PdcErrataFile.last(expected_count).each do |f|
        assert f.current?
        assert_equal errata, f.errata
        assert_equal mapping.brew_build, f.brew_build
        assert f.variant.is_a?(PdcVariant)
      end

      # Reload so we don't have stale current_files
      errata.reload

      # Sanity check variants and pdc_variants
      assert_equal 2, errata.pdc_variants.count
      assert_equal 2, errata.variants.count

      # Sanity check current_files and relarchlist
      assert_equal expected_count, errata.current_files.count
      assert_equal "Red Hat Ceph Storage MON - x86_64, Red Hat Ceph Storage OSD - x86_64", errata.relarchlist.join(', ')

      # Obsolete (should mark PdcErrataFile records as non-current)
      mapping.obsolete!
      PdcErrataFile.last(expected_count).each do |f|
        refute f.current?
      end
      assert mapping.removed_index.present?

      # Reload so we don't have stale current_files and relarchlist
      errata.reload

      # Sanity check release variants and relarchlist after obsoleting
      assert_equal 0, errata.variants.count
      assert_equal "", errata.relarchlist.join(', ')
    end
  end

  test "pdc product listings with correct arch be yield" do
    pdc_release = @p_e_r_b.pdc_release
    brew_build = @p_e_r_b.brew_build
    listings = YAML.load(File.read("#{Rails.root}/test/data/mock_ceph-2.1-ceph.yml"))
    # Mock live listings for following fetch operation
    # Mocked data looks like following, for the same variant, different arches have different rpms
    # table:
    #   :MON: !ruby/object:OpenStruct
    #     table:
    #       :x86_64: !ruby/object:OpenStruct
    #         table:
    #           :librgw2:
    #           - x86_64
    #           ......
    #       :aarch64: !ruby/object:OpenStruct
    #         table:
    #           :ceph-base:
    #           - aarch64
    #           ......
    #   ......
    PdcProductListing.expects(:fetch_live_listings).with(pdc_release, brew_build).returns(listings)
    # There is already cached listings for this pdc_release and brew_build
    # We need to fetch the mocked data and update cached listings
    ProductListing.for_pdc(true).find_or_fetch(pdc_release, brew_build, {use_cache: false})

    @p_e_r_b.build_product_listing_iterator do |_, _, _, arch_list|
      arches = arch_list.map(&:name)
      assert_equal 1, arches.length, "Unexpected number of arches: #{arches.to_a.join(',')}"
      assert arches.include?('x86_64'), "Unexpected arch: #{arches.first}"
      refute arches.include?('aarch64')
    end
  end
end
