require 'test_helper'

class BrewBuildTest < ActiveSupport::TestCase
  setup do
    @build = BrewBuild.find_by_id(74621)
    master_key = SigKey.find_by_name('master')

    dummy_value = 1000000001
    @build.brew_rpms.each do |rpm|
      dummy_value +=1
      md5 = Md5sum.new(:value => "MD5:#{dummy_value.to_s}", :sig_key => master_key, :brew_file => rpm)
      sha = Sha256sum.new(:value => "Sha256:#{dummy_value.to_s}", :sig_key => master_key, :brew_file => rpm)
      md5.save
      sha.save
    end
  end

  def get_checksum
     rpm_ids =  @build.brew_rpms.collect{ |rpm| rpm.id }
     md5_records = Md5sum.where('brew_file_id IN (?)', rpm_ids)
     sha256_records = Sha256sum.where('brew_file_id IN (?)', rpm_ids)
     return md5_records, sha256_records
  end

  test "delete checksums when signature revoked" do
    # make sure the checksums are not empty
    md5_records, sha256_records = get_checksum
    assert !md5_records.empty? && !sha256_records.empty?

    @build.revoke_signatures!

    # checksums should empty after the signature revoke
    md5_records, sha256_records = get_checksum
    assert md5_records.empty? && sha256_records.empty?
  end

  test "basic" do 
    pkg = Package.find_by_name 'kernel'
    assert pkg.valid?, "Package kernel invalid!"
    build = BrewBuild.new(:version => '2.4.21',
                          :release => '32.EL',
                          :package => pkg,
                          :nvr => 'kernel-2.4.21-32.EL')
    build.id = 1
    build.save!
  end

  test 'to_s' do
    build = BrewBuild.find_by_nvr!('autotrace-0.31.1-26.el6')
    assert_equal 'build autotrace-0.31.1-26.el6', "build #{build}"

    # Make sure it does something reasonable if there's no NVR
    empty_to_s = BrewBuild.new.to_s
    assert empty_to_s.present?
    assert empty_to_s.is_a?(String)
  end
end

class BrewBuildImportTest < ActiveSupport::TestCase
  setup do
    # This build must be valid but shouldn't yet be persisted.
    # Just clone a valid one with a new ID and nvr.
    @build = BrewBuild.new(BrewBuild.find(300002).attributes.except('id', 'nvr')).tap do |bb|
      bb.id = 12345
      bb.nvr = "#{bb.package.name}-1.2.3-4.5"
    end

    @ks_type = BrewArchiveType.find_by_name!('ks')
    @tar_type = BrewArchiveType.find_by_name!('tar')
    @msi_type = BrewArchiveType.find_by_name!('msi')
    @txt_type = BrewArchiveType.find_by_name!('txt')
    @jar_type = BrewArchiveType.find_by_name!('jar')
    @pom_type = BrewArchiveType.find_by_name!('pom')

    @fake_rpc_rpms = [
      {'id' => 100000010, 'arch' => 'x86_64', 'nvr' => 'some-rpm-1.0.0-1.0'},
      {'id' => 100000011, 'arch' => 'ppc64',  'nvr' => 'some-rpm-1.0.0-1.0'},
    ]

    # deliberately reused some of the rpm IDs for archives here
    @fake_rpc_image_archives = [
      {'id' => 100000010, 'type_id' => @ks_type.id, 'filename' => 'some-file.ks'},
      {'id' => 100000013, 'type_id' => @tar_type.id, 'arch' => 'x86_64', 'filename' => 'other-file.tar'},
    ]

    @fake_rpc_win_archives = [
      {'id' => 100000011, 'type_id' => @msi_type.id, 'filename' => 'some-file.msi'},
      {'id' => 100000015, 'type_id' => @txt_type.id, 'filename' => 'build.txt', 'relpath' => 'some/sub/path'},
    ]

    @fake_rpc_maven_archives = [
      {'id' => 100000016, 'type_id' => @jar_type.id, 'filename' => 'some-artifact-1.2.3.jar', 'group_id' => 'com.example', 'artifact_id' => 'my-artifact'},
      {'id' => 100000017, 'type_id' => @pom_type.id, 'filename' => 'some-artifact-1.2.3.pom', 'group_id' => 'org.example', 'artifact_id' => 'my-artifact'},
    ]

    @expected_rpms = [
      {'id_brew' => 100000010, 'arch_id' => Arch.find_by_name!('x86_64').id, 'name' => 'some-rpm-1.0.0-1.0', 'type' => 'BrewRpm' },
      {'id_brew' => 100000011, 'arch_id' => Arch.find_by_name!('ppc64').id,  'name' => 'some-rpm-1.0.0-1.0', 'type' => 'BrewRpm' },
    ]

    @expected_image_archives = [
      {'id_brew' => 100000010, 'brew_archive_type_id' => @ks_type.id, 'name' => 'some-file.ks', 'type' => 'BrewImageArchive'},
      {'id_brew' => 100000013, 'brew_archive_type_id' => @tar_type.id, 'arch_id' => Arch.find_by_name!('x86_64').id, 'name' => 'other-file.tar', 'type' => 'BrewImageArchive'},
    ]

    @expected_win_archives = [
      {'id_brew' => 100000011, 'brew_archive_type_id' => @msi_type.id, 'name' => 'some-file.msi', 'type' => 'BrewWinArchive'},
      {'id_brew' => 100000015, 'brew_archive_type_id' => @txt_type.id, 'name'  => 'build.txt', 'relpath' => 'some/sub/path', 'type' => 'BrewWinArchive'},
    ]

    @expected_maven_archives = [
      {'id_brew' => 100000016, 'brew_archive_type_id' => @jar_type.id, 'name' => 'some-artifact-1.2.3.jar', 'maven_groupId' => 'com.example', 'maven_artifactId' => 'my-artifact', 'type' => 'BrewMavenArchive'},
      {'id_brew' => 100000017, 'brew_archive_type_id' => @pom_type.id, 'name' => 'some-artifact-1.2.3.pom', 'maven_groupId' => 'org.example', 'maven_artifactId' => 'my-artifact', 'type' => 'BrewMavenArchive'},
    ]

    @slice_rpm_attrs = lambda{|f| f.attributes.slice('type', 'name', 'arch_id', 'id_brew')}
    @slice_archive_attrs = lambda{|f| f.attributes.slice('name', 'brew_archive_type_id', 'id_brew', 'type', 'arch_id', 'relpath', 'maven_groupId', 'maven_artifactId')}
    @slice_attrs = lambda{|f| (f.kind_of?(BrewRpm) ? @slice_rpm_attrs : @slice_archive_attrs).call(f)}
  end

  def get_file_attrs_for_test(bb)
    bb.brew_files.sort_by(&:id).map(&@slice_attrs).map{|h| h.reject{|k,v| v.nil?}}
  end

  test 'imports RPMs returned by listBuildRPMs' do
    Brew.any_instance.stubs(:listArchives => [])
    Brew.any_instance.expects(:listBuildRPMs).with(12345).returns(@fake_rpc_rpms)

    @build.import_files_from_rpc
    @build.save!

    import_attrs = @build.brew_files.sort_by(&:id).map(&@slice_attrs)
    assert_equal @expected_rpms, import_attrs
  end

  test 'imports image archives returned by listArchives' do
    Brew.any_instance.stubs(:listBuildRPMs => [])
    Brew.any_instance.expects(:listArchives).with(12345, nil, nil, nil, 'maven').returns([])
    Brew.any_instance.expects(:listArchives).with(12345, nil, nil, nil, 'win').returns([])
    Brew.any_instance.expects(:listArchives).with(12345, nil, nil, nil, 'image').returns(@fake_rpc_image_archives)

    @build.import_files_from_rpc
    @build.save!

    assert_equal @expected_image_archives, get_file_attrs_for_test(@build)
  end

  test 'imports maven archives returned by listArchives' do
    Brew.any_instance.stubs(:listBuildRPMs => [])
    Brew.any_instance.expects(:listArchives).with(12345, nil, nil, nil, 'maven').returns(@fake_rpc_maven_archives)
    Brew.any_instance.expects(:listArchives).with(12345, nil, nil, nil, 'win').returns([])
    Brew.any_instance.expects(:listArchives).with(12345, nil, nil, nil, 'image').returns([])

    @build.import_files_from_rpc
    @build.save!

    assert_equal @expected_maven_archives, get_file_attrs_for_test(@build)
  end

  test 'imports win archives returned by listArchives' do
    Brew.any_instance.stubs(:listBuildRPMs => [])
    Brew.any_instance.expects(:listArchives).with(12345, nil, nil, nil, 'maven').returns([])
    Brew.any_instance.expects(:listArchives).with(12345, nil, nil, nil, 'win').returns(@fake_rpc_win_archives)
    Brew.any_instance.expects(:listArchives).with(12345, nil, nil, nil, 'image').returns([])

    @build.import_files_from_rpc
    @build.save!

    assert_equal @expected_win_archives, get_file_attrs_for_test(@build)
  end

  test 'creates archive types as needed' do
    Brew.any_instance.stubs(:listBuildRPMs => [])
    Brew.any_instance.expects(:listArchives).with(12345, nil, nil, nil, 'maven').returns([])
    Brew.any_instance.expects(:listArchives).with(12345, nil, nil, nil, 'win').returns([])
    Brew.any_instance.expects(:listArchives).with(12345, nil, nil, nil, 'image').returns([
      {'id' => 100000018, 'type_id' => 99998, 'type_name' => 'quux', 'type_description' => 'description of quux', 'type_extensions' => 'quux quu', 'filename' => 'some-file.quux'},
    ])

    @build.import_files_from_rpc
    @build.save!

    assert_equal 1, @build.brew_files.length

    archive_type = @build.brew_files.first.archive_type
    assert_not_nil archive_type
    assert_equal 99998, archive_type.id
    assert_equal 'quux', archive_type.name
    assert_equal 'description of quux', archive_type.description
    assert_equal 'quux quu', archive_type.extensions
  end

  test 'updates archive types as needed' do
    @ks_type = BrewArchiveType.find_by_name!('ks')

    Brew.any_instance.stubs(:listBuildRPMs => [])
    Brew.any_instance.expects(:listArchives).with(12345, nil, nil, nil, 'maven').returns([])
    Brew.any_instance.expects(:listArchives).with(12345, nil, nil, nil, 'win').returns([])
    Brew.any_instance.expects(:listArchives).with(12345, nil, nil, nil, 'image').returns([
      {'id' => 100000018, 'type_id' => @ks_type.id, 'type_name' => 'ks', 'type_description' => 'Updated ks description', 'type_extensions' => 'ks kickstart', 'filename' => 'some-file.ks'},
    ])

    @build.import_files_from_rpc
    @build.save!

    assert_equal 1, @build.brew_files.length

    archive_type = @build.brew_files.first.archive_type
    assert_not_nil archive_type
    assert_equal @ks_type.id, archive_type.id
    assert_equal 'ks', archive_type.name
    assert_equal 'Updated ks description', archive_type.description
    assert_equal 'ks kickstart', archive_type.extensions
  end

  test 'ignores any files which already exist' do
    dupe_rpm = @fake_rpc_rpms.first.dup
    dupe_archive = @fake_rpc_maven_archives.first.dup

    (dupe_rpm['id'],dupe_archive['id']) = [BrewRpm, BrewMavenArchive].map(&:first).map(&:id_brew)

    Brew.any_instance.expects(:listArchives).with(12345, nil, nil, nil, 'image').returns([])
    Brew.any_instance.expects(:listArchives).with(12345, nil, nil, nil, 'win').returns([])
    Brew.any_instance.expects(:listArchives).with(12345, nil, nil, nil, 'maven').returns([dupe_archive])
    Brew.any_instance.expects(:listBuildRPMs).with(12345).returns([dupe_rpm])

    @build.import_files_from_rpc
    @build.save!

    # The BrewFiles records which already existed remain unmodified, so they're associated
    # with their original build - not this one.
    assert_equal 0, @build.brew_files.length
  end

  # Bug 1189351
  test 'can import archive with same id_brew as an RPM' do
    id = 3743667
    # using an RPM where id = id_brew to ensure code is ignoring _both_ columns
    assert BrewRpm.where('id = id_brew').where(:id => id).exists?, 'fixture problem'
    fake_image = {
      'id' => id, 'type_id' => @ks_type.id, 'filename' => 'some-file.ks'
    }

    Brew.any_instance.expects(:listArchives).with(12345, nil, nil, nil, 'image').returns([fake_image])
    Brew.any_instance.expects(:listArchives).with(12345, nil, nil, nil, 'win').returns([])
    Brew.any_instance.expects(:listArchives).with(12345, nil, nil, nil, 'maven').returns([])
    Brew.any_instance.expects(:listBuildRPMs).with(12345).returns([])

    assert_difference('BrewFile.count', 1) do
      @build.import_files_from_rpc
      @build.save!
    end

    file = @build.brew_files.first
    assert_equal id, file.id_brew
    assert_not_equal id, file.id
    assert_equal 'BrewImageArchive', file.type
  end

  test 'can import RPM with the same id_brew as an archive' do
    id = 698253
    assert BrewImageArchive.where('id = id_brew').where(:id => id).exists?, 'fixture problem'
    fake_rpm = {
      'id' => id, 'arch' => 'x86_64', 'nvr' => 'some-rpm-1.0.0-1.0'
    }

    Brew.any_instance.expects(:listArchives).with(12345, nil, nil, nil, 'image').returns([])
    Brew.any_instance.expects(:listArchives).with(12345, nil, nil, nil, 'win').returns([])
    Brew.any_instance.expects(:listArchives).with(12345, nil, nil, nil, 'maven').returns([])
    Brew.any_instance.expects(:listBuildRPMs).with(12345).returns([fake_rpm])

    assert_difference('BrewFile.count', 1) do
      @build.import_files_from_rpc
      @build.save!
    end

    file = @build.brew_files.first
    assert_equal id, file.id_brew
    assert_not_equal id, file.id
    assert_equal 'BrewRpm', file.type
  end

  test "get cached brew files" do
    brew_builds = BrewBuild.last(3)

    expected = brew_builds.each_with_object(HashList.new) do |brew_build,h|
     expected_files = brew_build.brew_files.sort

     # cached_brew_files should returns same results as brew_files if not cached
     assert_array_equal expected_files, brew_build.cached_brew_files.sort

     h[brew_build] = expected_files
    end

    # do caching
    Thread.current[:cached_files] = BrewBuild.prepare_cached_files(brew_builds.map(&:id))
    # never call brew_files again
    BrewBuild.any_instance.expects(:brew_files).never

    brew_builds.each do |brew_build|
      assert_array_equal expected[brew_build], brew_build.cached_brew_files.sort
    end
  end
end
