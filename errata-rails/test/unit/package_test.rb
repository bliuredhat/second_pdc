require 'test_helper'

class PackageTest < ActiveSupport::TestCase
  setup do
    @test_package = Package.first
    @test_7Client = Variant.find_by_name('7Client')
    @test_5Client = Variant.find_by_name('5Client')
    @test_push_targets = PushTarget.where(:name => %w[rhn_live cdn rhn_stage])
  end

  test "assign owner and responsibility up creation" do
    pkg = Package.create(:name => 'foo')
    assert_instance_of User, pkg.qe_owner
    assert_instance_of QualityResponsibility, pkg.quality_responsibility
  end

  test "create from name" do
    Package.make_from_name('foo')
    assert Package.find_by_name('foo')
    assert Package.make_from_name(Package.last.name)
  end

  test "create from name strips spaces" do
    Package.make_from_name('foo')
    p = Package.find_by_name('foo')
    assert p
    assert_equal p, Package.make_from_name('  foo  ')
  end

  test "get package suppported push types by variant" do
    # Make sure the restriction is not already exists so that this test can continue.
    refute(PackageRestriction.exists?(["package_id = ? and variant_id = ?", @test_package, @test_7Client]),
    "Fixture error: the fixture data had changed.")
    # Make sure the variant supports all the push types needed for this test
    assert_array_equal @test_push_targets, @test_7Client.push_targets

    # if no restriction is set to the package, then its push types should reflect the variant push types.
    package_push_types = @test_package.supported_push_types_by_variant(@test_7Client)
    assert_equal @test_7Client.supported_push_types, package_push_types

    expected_push_targets = @test_push_targets.limit(2)
    PackageRestriction.create!(
      :package => @test_package,
      :variant => @test_7Client,
      :push_targets => expected_push_targets
    )

    package_push_types = @test_package.supported_push_types_by_variant(@test_7Client)
    assert_equal expected_push_targets.map(&:push_type), package_push_types
  end

  test "package supports cdn or rhn" do
    # RHEL 5 does not support cdn
    refute @test_package.supports_cdn?(@test_5Client)
    # RHEL 7 does support cdn and rhn
    assert @test_package.supports_rhn?(@test_7Client)
    assert @test_package.supports_cdn?(@test_7Client)

    # update the variant to support rhn stage only
    update_variant_push_targets(@test_7Client, %w[rhn_stage])
    assert @test_package.supports_rhn?(@test_7Client)

    # update the variant to support cdn only
    update_variant_push_targets(@test_7Client, %w[cdn])
    refute @test_package.supports_rhn?(@test_7Client)
  end

  test "find_or_create_packages returns empty if no component is given" do
    list = Package.find_or_create_packages!([])
    assert_equal({}, list)
  end

  test "find_or_create_packages returns new and existing packages" do
    existing = Package.limit(10).map(&:name)
    new_packages = ['one_piece', 'naruto']

    expected_packages = existing + new_packages

    list = {}
    assert_difference('Package.count', 2) do
      list = Package.find_or_create_packages!(expected_packages)
    end

    # make sure the created packages are correct
    assert_array_equal new_packages.sort, Package.last(2).map(&:name).sort

    # make sure the method returns the correct list of packages
    assert_array_equal expected_packages.sort, list.keys.sort

    list.each_pair do |package_name, package_obj|
      assert package_obj.kind_of?(Package)
      assert_equal package_name, package_obj.name
    end
  end

  def update_variant_push_targets(variant, targets)
    variant.update_attributes!(:push_targets => PushTarget.where(:name => targets))
  end

  test "get package supported push types" do
    # get a package with restrictions for testing
    restriction =  PackageRestriction.first
    package_1 = restriction.package
    variant = restriction.variant

    (package_2, package_3) = Package.last(2).map do |package|
      assert_equal [], package.package_restrictions.to_a, "Fixture error, package has restrictions now."
      package
    end

    expected = {
      package_1 => restriction.supported_push_types,
      # if package has no restrictions, then the variant push types should be returned
      package_2 => variant.supported_push_types,
    }

    expected.each_pair do |package, expected_push_types|
      actual_push_types = package.supported_push_types_by_variant(variant)
      assert_equal expected_push_types, actual_push_types
    end

    # now test to cache the package restrictions
    Thread.current[:cached_restrictions] = Package.prepare_cached_package_restrictions([package_1,package_2].map(&:id))

    expected.each_pair do |package, expected_push_types|
      # never do database query again
      package.expects(:package_restrictions).never
      actual_push_types = package.supported_push_types_by_variant(variant)
      assert_equal expected_push_types, actual_push_types
    end

    # make sure not cached data also return the correct results
    actual_push_types = package_3.supported_push_types_by_variant(variant)
    assert_equal variant.supported_push_types, actual_push_types
  end
end
