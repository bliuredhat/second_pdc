require 'test_helper'

class MultiProductCdnRepoMapTest < ActiveSupport::TestCase
  test 'signing keys must match' do
    pkg = Package.find_by_name 'sblim'
    src_repo = CdnRepo.find_by_name 'rhel-6-client-rpms__6Client__i686'
    dest_repo = CdnRepo.find_by_name 'cdnrepo-i686'

    map = MultiProductCdnRepoMap.new(:package => pkg,
                                     :origin_cdn_repo => src_repo,
                                     :origin_product_version_id => src_repo.variant.product_version.id,
                                     :destination_product_version_id => dest_repo.variant.product_version.id,
                                     :destination_cdn_repo => dest_repo)
    refute map.valid?
    assert_equal errors_to_string(map),
      'Origin product version Signing keys must match between product versions. RHEL-6 has signing key redhatrelease2; whereas RHEL-6-RHCI1 has key test.'
  end

  test 'valid mapping can be created' do
    pkg = Package.find_by_name 'sblim'
    src_repo = CdnRepo.find_by_name 'rhel-6-client-rpms__6Client__i686'
    dest_repo = CdnRepo.find_by_name 'rhel-6-server-rhev-agent-rpms__6Server__x86_64'

    map = MultiProductCdnRepoMap.new(:package => pkg,
                                     :origin_cdn_repo => src_repo,
                                     :origin_product_version_id => src_repo.variant.product_version.id,
                                     :destination_product_version_id => dest_repo.variant.product_version.id,
                                     :destination_cdn_repo => dest_repo)

    assert_valid(map)
  end

  test 'mapping must be unique' do
    pkg = Package.find_by_name 'sblim'
    src_repo = CdnRepo.find_by_name 'rhel-6-client-rpms__6Client__i686'
    dest_repo = CdnRepo.find_by_name 'rhel-6-server-rhev-agent-rpms__6Server__x86_64'

    attrs = {
      :package => pkg,
      :origin_cdn_repo => src_repo,
      :origin_product_version_id => src_repo.variant.product_version.id,
      :destination_product_version_id => dest_repo.variant.product_version.id,
      :destination_cdn_repo => dest_repo
    }
    map = MultiProductCdnRepoMap.new(attrs)
    assert_valid(map)
    map.save!

    dupe_map = MultiProductCdnRepoMap.new(attrs)
    refute dupe_map.valid?
    assert_equal errors_to_string(dupe_map),
      'Origin cdn repo A mapping already exists for rhel-6-client-rpms__6Client__i686 => rhel-6-server-rhev-agent-rpms__6Server__x86_64 for package sblim'
  end

  test 'origin must be active' do
    pkg = Package.find_by_name 'sblim'
    src_repo = CdnRepo.find_by_name 'rhel-6-client-rpms__6Client__i686'
    dest_repo = CdnRepo.find_by_name 'rhel-6-server-rhev-agent-rpms__6Server__x86_64'

    CdnRepoLink.where(:cdn_repo_id => src_repo).destroy_all

    map = MultiProductCdnRepoMap.new(:package => pkg,
                                     :origin_cdn_repo => src_repo,
                                     :origin_product_version_id => src_repo.variant.product_version.id,
                                     :destination_product_version_id => dest_repo.variant.product_version.id,
                                     :destination_cdn_repo => dest_repo)
    refute map.valid?
    assert_equal errors_to_string(map),
      'Origin cdn repo rhel-6-client-rpms__6Client__i686 is not an active Cdn Repo of RHEL-6'
  end

  test 'destination must be active' do
    pkg = Package.find_by_name 'sblim'
    src_repo = CdnRepo.find_by_name 'rhel-6-client-rpms__6Client__i686'
    dest_repo = CdnRepo.find_by_name 'rhel-6-server-rhev-agent-rpms__6Server__x86_64'

    CdnRepoLink.where(:cdn_repo_id => dest_repo).destroy_all

    map = MultiProductCdnRepoMap.new(:package => pkg,
                                     :origin_cdn_repo => src_repo,
                                     :origin_product_version_id => src_repo.variant.product_version.id,
                                     :destination_product_version_id => dest_repo.variant.product_version.id,
                                     :destination_cdn_repo => dest_repo)
    refute map.valid?
    assert_equal errors_to_string(map),
      'Destination cdn repo rhel-6-server-rhev-agent-rpms__6Server__x86_64 is not an active Cdn Repo of RHEL-6-RHEV'
  end
end
