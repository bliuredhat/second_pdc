require 'test_helper'

class BuildGuardTest < ActiveSupport::TestCase
  setup do
    @advisory_with_builds = Errata.find 10858
    @bg = BuildGuard.new
  end

  # https://bugzilla.redhat.com/show_bug.cgi?id=1358105
  test 'blocks on multi product problems' do
    # Verify that is multi product and is valid
    errata = Errata.find 13147
    assert errata.supports_multiple_product_destinations?
    assert @bg.transition_ok?(errata), @bg.failure_message(errata)

    # Eliminate a product listing cache, which will break multi product mappings
    build = BrewBuild.find_by_nvr 'sblim-cim-client2-2.1.3-2.el6'
    rhev = ProductVersion.find_by_name "RHEL-6-RHEV"
    rhev_listing = ProductListingCache.find_by_product_version_id_and_brew_build_id(rhev, build)
    rhev_cache = rhev_listing.get_listing
    rhev_listing.set_listing({})
    rhev_listing.save!
    refute @bg.transition_ok? errata
    assert_equal "Build sblim-cim-client2-2.1.3-2.el6 has missing product listings for multi-product mapped product versions: RHEL-6-RHEV",
                 @bg.failure_message(errata)

    # Eliminate second product listing cache, both product versions show in warning
    rhev_s = ProductVersion.find_by_name "RHEL-6-RHEV-S"
    rhev_s_listing = ProductListingCache.find_by_product_version_id_and_brew_build_id(rhev_s, build)
    rhev_s_cache = rhev_s_listing.get_listing
    rhev_s_listing.set_listing({})
    rhev_s_listing.save!
    refute @bg.transition_ok? errata
    assert_equal "Build sblim-cim-client2-2.1.3-2.el6 has missing product listings for multi-product mapped product versions: RHEL-6-RHEV, RHEL-6-RHEV-S",
      @bg.failure_message(errata)


    # Fix product listings, transition is now ok
    rhev_listing.set_listing(rhev_cache)
    rhev_listing.save!
    rhev_s_listing.set_listing(rhev_s_cache)
    rhev_s_listing.save!
    assert @bg.transition_ok?(errata), @bg.failure_message(errata)

    # Deleting product listing cache objects should have the same effect
    rhev_listing.delete
    refute @bg.transition_ok? errata
    assert_equal "Build sblim-cim-client2-2.1.3-2.el6 has missing product listings for multi-product mapped product versions: RHEL-6-RHEV",
                 @bg.failure_message(errata)

    rhev_s_listing.delete
    refute @bg.transition_ok? errata
    assert_equal "Build sblim-cim-client2-2.1.3-2.el6 has missing product listings for multi-product mapped product versions: RHEL-6-RHEV, RHEL-6-RHEV-S",
                 @bg.failure_message(errata)
  end

  test 'advisory without builds blocked' do
    advisory_without_builds = Errata.find 22001
    assert advisory_without_builds.brew_builds.blank?
    refute advisory_without_builds.text_only?
    assert_equal 'NEW_FILES', advisory_without_builds.status
    refute @bg.transition_ok?(advisory_without_builds)
    assert_equal "No builds in advisory", @bg.failure_message(advisory_without_builds)
  end

  test 'text only advisory without builds is ok' do
    advisory_without_builds = Errata.find 22001
    refute @bg.transition_ok?(advisory_without_builds)
    # Make text_only, transition should now be ok
    advisory_without_builds.stubs('text_only?':true)
    assert @bg.transition_ok?(advisory_without_builds), @bg.failure_message(advisory_without_builds)
    assert_equal '', @bg.ok_message(advisory_without_builds)

  end

  test 'advisory with builds is ok' do
    assert @advisory_with_builds.brew_builds.any?
    refute @advisory_with_builds.text_only?
    assert_equal 'NEW_FILES', @advisory_with_builds.status
    assert @bg.transition_ok?(@advisory_with_builds), @bg.failure_message(@advisory_with_builds)
  end

  test 'advisory without current files is blocked' do
    ErrataFile.where(errata_id: @advisory_with_builds).delete_all
    refute @bg.transition_ok?(@advisory_with_builds)
    assert_equal "Missing current files records for 1 build", @bg.failure_message(@advisory_with_builds)
    # https://bugzilla.redhat.com/show_bug.cgi?id=1459390
    pdc_errata = PdcErrata.find 21131
    PdcErrataFile.where(errata_id: pdc_errata).delete_all
    refute @bg.transition_ok?(pdc_errata)
    assert_equal "Missing current files records for 1 build", @bg.failure_message(pdc_errata)
  end

  test 'advisory without current files and without product listings is blocked' do
    ErrataBrewMapping.stubs(without_current_files: [1,2,3])
    ErrataBrewMapping.stubs(without_product_listings: [1,2,3])
    refute @bg.transition_ok?(@advisory_with_builds)
    assert_equal "Missing 3 product listings, Missing current files records for 3 builds", @bg.failure_message(@advisory_with_builds)
  end

  test 'Advisory without product listings is blocked' do
    ErrataBrewMapping.stubs(without_product_listings: [1,2,3])
    refute @bg.transition_ok?(@advisory_with_builds)
    assert_equal "Missing 3 product listings", @bg.failure_message(@advisory_with_builds)
  end
end
