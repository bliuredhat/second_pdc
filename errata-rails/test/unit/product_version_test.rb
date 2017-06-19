require 'test_helper'

class ProductVersionTest < ActiveSupport::TestCase
  fixtures :product_versions

  def test_base_product_version
    pv = ProductVersion.find_by_name 'RHEL-5'
    assert !pv.is_zstream?

    # Try non z-stream. Should not work
    bad = ProductVersion.find_by_name 'RHEL-4'
    assert !bad.is_zstream?
    bad.base_product_version = pv
    assert !bad.valid?
    assert_equal 2, bad.errors.count, "More errors than expected!: #{bad.errors}"
    assert bad.errors.has_key?(:base_product_version)

    # 5.8.Z should already be set with base product version RHEL 5
    zpv = ProductVersion.find_by_name 'RHEL-5.8.Z'
    assert zpv.is_zstream?
    assert_equal pv, zpv.base_product_version
    assert zpv.valid?, zpv.errors.full_messages.join(', ')

    zpv.update_attribute(:base_product_version, nil)
    assert zpv.valid?

    zpv.base_product_version = pv
    zpv.save!

    # Add a second RHEL 5 z stream. Should fail due to uniqueness constraint
    z59 = RhelRelease.create!(:name => 'RHEL-5.9.Z', :description => '5.9.Z')
    assert z59.is_zstream?
    dup_z = ProductVersion.create!(:name => 'RHEL-5.9.Z',
                                   :description => '5.9.Z',
                                   :rhel_release => z59,
                                   :product => zpv.product,
                                   :sig_key => zpv.sig_key)

    assert dup_z.is_zstream?
    dup_z.base_product_version = pv
    assert !dup_z.valid?
    assert_equal 1, dup_z.errors.count, "More errors than expected!: #{dup_z.errors}"
    assert dup_z.errors.has_key?(:base_product_version_id)
  end

  def test_released_package_for_base_product_version
    ProductListing.stubs(:get_brew_product_listings => {})

    build = BrewBuild.find_by_nvr 'tetex-3.0-33.13.el5'
    pv = ProductVersion.find_by_name 'RHEL-5'
    zpv = ProductVersion.find_by_name 'RHEL-5.8.Z'

    assert ProductListingCache.exists?(['product_version_id = ? and brew_build_id = ?',
                                        pv, build])

    assert ProductListingCache.exists?(['product_version_id = ? and brew_build_id = ?',
                                        zpv, build])


    # Verify no released packages exist for either product version.
    assert !ReleasedPackage.exists?(['brew_build_id = ? and product_version_id = ?', build, pv])
    assert !ReleasedPackage.exists?(['brew_build_id = ? and product_version_id = ?', build, zpv])

    zpv.base_product_version = pv
    zpv.save!

    update = ReleasedPackageUpdate.create!(:reason => 'testing', :user_input => {})
    ReleasedPackage.make_released_packages_for_build(build.nvr, zpv, update)
    # Verify released packages exist for both product versions.
    assert ReleasedPackage.exists?(['brew_build_id = ? and product_version_id = ?', build, zpv])
    assert ReleasedPackage.exists?(['brew_build_id = ? and product_version_id = ?', build, pv])

    # Check expected RP count
    assert_equal 63, ReleasedPackage.get_released_packages(build.package.name, pv.name).length
    # Should be less as is server_only
    assert_equal 63, ReleasedPackage.get_released_packages(build.package.name, zpv.name).length
  end

  test "variant rhel release mismatch" do
    pv = ProductVersion.find_by_name('RHEL-6')
    assert_valid pv
    pv.variants[0].update_attribute(:rhel_release_id, RhelRelease.find_by_name('RHEL-5').id)
    refute pv.valid?
    assert_errors_include(pv, 'Rhel release does not match that of variants: RHEL-6 versus RHEL-5')
  end

  test "variant rhel release mismatch multiple rhel releases" do
    pv = ProductVersion.find_by_name('RHEL-6')
    assert_valid pv
    pv.variants[0].update_attribute(:rhel_release_id, RhelRelease.find_by_name('RHEL-4').id)
    pv.variants[1].update_attribute(:rhel_release_id, RhelRelease.find_by_name('RHEL-5').id)
    refute pv.valid?
    assert_errors_include(pv, 'Rhel release does not match that of variants: RHEL-6 versus RHEL-4, RHEL-5')
  end

  # Bug 1199945
  test "can combine with_active_product and exclude_ids" do
    active = ProductVersion.with_active_product.map(&:id)
    assert active.length >= 3, 'fixture problem'

    with_exclusions = ProductVersion.with_active_product.exclude_ids(active[0..1])
    assert_equal active.length - 2, with_exclusions.length
  end
end
