require 'test_helper'

class CdnRepoTest < ActiveSupport::TestCase
  setup do
    rhel_variant = Variant.find_by_name("6Client")
    arch = Arch.find_by_name("x86_64")
    @parent_repo = rhel_variant.cdn_repos.where("arch_id = ?", arch).first

    # create a sub variant
    variant = Variant.create(:product_version => rhel_variant.product_version,
                             :rhel_variant => rhel_variant,
                             :name => '6Client-Child',
                             :description => 'Child for 6Client')

    # attach a repo to a sub variant
    @child_repo = CdnBinaryRepo.create(:name => "rhel-6-client-child-rpms__6Client__x86_64",
                                       :arch => arch,
                                       :release_type => 'PrimaryCdnRepo',
                                       :variant => variant)
  end

  test "is parent" do
    assert @parent_repo.is_parent?
    refute @child_repo.is_parent?
  end

  test "get parent repo" do
    assert_equal @parent_repo.get_parent, @parent_repo
    assert_equal @child_repo.get_parent, @parent_repo
  end

  test "get short release type name" do
    tests = {:PrimaryCdnRepo => 'Primary', :EusCdnRepo => 'EUS', :FastTrackCdnRepo => 'FastTrack', :LongLifeCdnRepo => 'LongLife'}
    tests.each_pair do |key, value|
      @parent_repo.release_type = key.to_s
      assert_equal @parent_repo.short_release_type, value
    end
  end

  test "get short content type name" do
    tests = {:CdnBinaryRepo => 'Binary', :CdnSourceRepo => 'Source', :CdnDebuginfoRepo => 'Debuginfo'}
    tests.each_pair do |key, value|
      @parent_repo.type = key.to_s
      assert_equal @parent_repo.short_type, value
    end
  end

  test "returns short type" do
    assert_equal 'Binary', CdnBinaryRepo.last.short_type
    assert_equal 'Debuginfo', CdnDebuginfoRepo.last.short_type
  end

  test "cdn_content_set and cdn_content_set_for_tps" do
    [
      ['rhel-6-server-rhevm-3_DOT_1-rpms__6Server__x86_64',
       'rhel-6-server-rhevm-3_DOT_1-rpms',
       'rhel-6-server-rhevm-3.1-rpms'],

      ['rhsc-2_DOT_1-for-rhel-6-server-rpms__x86_64',
       'rhsc-2_DOT_1-for-rhel-6-server-rpms',
       'rhsc-2.1-for-rhel-6-server-rpms'],

      ['rhel-6-workstation-rhev-agent-rpms__6_DOT_5__x86_64',
       'rhel-6-workstation-rhev-agent-rpms',
       'rhel-6-workstation-rhev-agent-rpms'],

    ].each do |name, expected_cdn_content_set, expected_cdn_content_set_for_tps|
      cdn_repo = CdnRepo.new
      cdn_repo.stubs(:name).returns(name)
      assert_equal expected_cdn_content_set, cdn_repo.cdn_content_set
      assert_equal expected_cdn_content_set_for_tps, cdn_repo.cdn_content_set_for_tps
    end

  end

  test 'destroying CDN repo schedules regeneration of tps queue' do
    TpsQueue.expects(:schedule_publication)
    CdnRepo.find(1358).destroy
  end

  test "test repo name format" do
    invalid_cdn_repo = CdnRepo.new(:name => "rhel-6-server-rhev/m-3.1-rpms")
    refute invalid_cdn_repo.valid?
    assert_errors_include(invalid_cdn_repo, "Name contains illegal character '.'.")
    assert_errors_include(invalid_cdn_repo, "Name contains illegal character '/'.")
  end

  test "docker repo name can contain dot characters" do
    # Name with dots is rejected for non-Docker repo
    repo = CdnRepo.new(
      :name => 'test.repo.name.with.dots',
      :type => 'CdnBinaryRepo',
      :arch => Arch.find_by_name('x86_64'),
      :variant => Variant.find_by_name('7Server')
    )

    refute repo.valid?
    assert_errors_include(repo, "Name contains illegal character '.'.")

    # For Docker repo, name with dots is OK
    repo.type = 'CdnDockerRepo'
    assert repo.valid?
  end
end
