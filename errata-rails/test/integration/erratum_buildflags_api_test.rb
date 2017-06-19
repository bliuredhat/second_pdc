require 'test_helper'

class ErratumBuildFlagsApiTest < ActionDispatch::IntegrationTest
  setup do
    auth_as devel_user
  end

  test 'buildflags GET baseline test' do
    with_baselines('api/v1/buildflags', %r{errata_(\d+).json$}) do |file,id|
      get "/api/v1/erratum/#{id}/buildflags"
      formatted_json_response
    end
  end

  test 'overwriting flags with the same value does nothing' do
    put_json '/api/v1/erratum/16409/buildflags', {
      :file_type => 'rpm',
      :flags => ['buildroot-push'],
    }
    assert_testdata_equal 'api/v1/buildflags/put_noop.json', formatted_json_response
  end

  test 'can unset build flags' do
    put_json '/api/v1/erratum/16409/buildflags', {
      # no criteria means all mappings - will unset any set build flags
      :flags => [],
    }
    assert_testdata_equal 'api/v1/buildflags/unset_all.json', formatted_json_response
    assert_equal [], Errata.find(16409).build_mappings.
      select{|m| m.flags.any?}
  end

  test 'cannot set bogus flags' do
    put_json '/api/v1/erratum/16409/buildflags', {
      :file_type => 'rpm',
      :flags => ['made-up-flag'],
    }
    assert_testdata_equal 'api/v1/buildflags/put_bogus.json', formatted_json_response
  end

  test 'cannot set conflicting flags' do
    put_json '/api/v1/erratum/16409/buildflags', [
      { :file_type => 'rpm',
        :flags => ['some-flag', 'other-flag'] },
      { :build => 'spice-client-msi-3.4-4',
        :flags => ['some-flag', 'different-flag'] },
    ]
    assert_testdata_equal 'api/v1/buildflags/put_conflict.json', formatted_json_response
  end

  test 'cannot set buildroot-push on non-rpm mapping' do
    put_json '/api/v1/erratum/19029/buildflags', {
      # this advisory has RPM and non-RPM mappings; since we don't
      # specify type, we try to set this flag on all mappings, and
      # it'll be rejected for the non-RPM mappings
      :flags => ['buildroot-push'],
    }
    assert_testdata_equal 'api/v1/buildflags/put_invalid_type.json', formatted_json_response
    # and verify that even the RPM mapping didn't get flags (should be
    # transactional)
    assert_equal [], Errata.find(19029).build_mappings.
      select{|m| m.flags.any?}
  end

  test 'set buildflags on single mapping' do
    ProductVersion.any_instance.stubs(:permitted_build_flags => ['buildroot-push'].to_set)
    e = Errata.find(7517)
    assert e.build_mappings.select{|m| m.flags.any?}.empty?

    put_json '/api/v1/erratum/7517/buildflags', {
      :build => 'classads-1.0-2.el4',
      :product_version => 'RHEL-4-MRG-Grid-1.0',
      :file_type => 'rpm',
      :flags => ['buildroot-push'],
    }
    assert_testdata_equal 'api/v1/buildflags/put_single.json', formatted_json_response

    mapping = e.reload.build_mappings.select{|m| m.flags.any?}
    assert_equal 1, mapping.length

    mapping = mapping.first
    assert_equal ['buildroot-push'], mapping.flags.to_a
    assert_equal BrewBuild.find_by_nvr!('classads-1.0-2.el4'), mapping.brew_build
    assert_equal ProductVersion.find_by_name!('RHEL-4-MRG-Grid-1.0'), mapping.product_version
    assert_nil mapping.brew_archive_type
  end

  test 'set buildflags by product version' do
    ProductVersion.any_instance.stubs(:permitted_build_flags => ['buildroot-push'].to_set)
    e = Errata.find(7517)
    assert e.build_mappings.select{|m| m.flags.any?}.empty?

    put_json '/api/v1/erratum/7517/buildflags', {
      :product_version => 'RHEL-4-MRG-Grid-1.0',
      :flags => ['buildroot-push'],
    }
    assert_testdata_equal 'api/v1/buildflags/put_by_pv.json', formatted_json_response

    mappings = e.reload.build_mappings.select{|m| m.flags.any?}
    assert_equal 2, mappings.length
    assert_equal [ProductVersion.find_by_name!('RHEL-4-MRG-Grid-1.0')], mappings.map(&:product_version).uniq
    assert_equal [['buildroot-push']], mappings.map(&:flags).map(&:to_a).uniq
  end

  test 'set buildflags by multiple criteria' do
    ProductVersion.any_instance.stubs(:permitted_build_flags => ['buildroot-push'].to_set)
    e = Errata.find(7517)

    pv = ProductVersion.find_by_name!('RHEL-4-MRG-Grid-1.0')
    build = BrewBuild.find_by_nvr!('qpidc-0.2.667603-16.el4')

    put_json '/api/v1/erratum/7517/buildflags', [
      {
        :product_version => 'RHEL-4-MRG-Grid-1.0',
        :flags => ['buildroot-push'],
      },
      {
        :build => 'qpidc-0.2.667603-16.el4',
        :flags => ['buildroot-push'],
      },
    ]
    assert_testdata_equal 'api/v1/buildflags/put_multi1.json', formatted_json_response

    mappings1 = e.reload.build_mappings.select{|m| m.flags.any?}
    assert_equal 4, mappings1.length
    mappings1.each do |m|
      assert( m.product_version == pv || m.brew_build == build,
        "mismatch: #{m.inspect}")
      assert_equal ['buildroot-push'], m.flags.to_a
    end

    put_json '/api/v1/erratum/7517/buildflags', [
      {
        # this should unset flags on one of the qpidc mappings
        :product_version => 'RHEL-4-MRG-Messaging-1.0',
        :build => 'qpidc-0.2.667603-16.el4',
        :flags => [],
      },
      {
        :build => 72811,
        :flags => ['buildroot-push'],
      },
    ]
    assert_testdata_equal 'api/v1/buildflags/put_multi2.json', formatted_json_response

    mappings1.each(&:reload)
    mappings2 = e.reload.build_mappings.select{|m| m.flags.any?}
    added_flags = mappings2 - mappings1
    removed_flags = mappings1 - mappings2

    assert_equal 1, added_flags.length
    assert_equal 1, removed_flags.length

    assert_equal 72811, added_flags.first.brew_build_id
    assert_equal 'RHEL-4-MRG-Messaging-1.0', removed_flags.first.product_version.name
  end
end
