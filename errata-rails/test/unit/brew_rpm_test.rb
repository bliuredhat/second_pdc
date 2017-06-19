require 'test_helper'

class BrewRpmTest < ActiveSupport::TestCase

  def next_id_brew
    BrewRpm.pluck('max(id_brew)').first + 100
  end

  setup do
    # Overwrite the private method in the original class
    class ::BrewRpm
      public :generate_checksum
    end

    @test_rpm = BrewRpm.create!(
      :id_brew => next_id_brew,
      :package => Package.first,
      :brew_build => BrewBuild.first,
      :name => "test-1.0-1",
      :arch => Arch.last)

    assert @test_rpm.valid?
  end

  teardown do
    # Set method it back to private
    class ::BrewRpm
      private :generate_checksum
    end
  end

  def create_test_brew_rpm(nvr, epoch = 0)
    return BrewRpm.create!(
      :id_brew => next_id_brew,
      :package => Package.first,
      :brew_build => BrewBuild.first,
      :name => nvr,
      :arch => Arch.last,
      :epoch => epoch)
  end

  test "get md5 checksum by brew rpm" do
    expected_md5 = "ae2b1fca515949e5d54fb22b8ed95575"
    BrewRpm.any_instance.expects(:generate_checksum).once.returns(expected_md5)
    assert_difference 'Md5sum.count', 1 do
      md5sum = @test_rpm.md5sum
      assert_equal expected_md5, md5sum
    end
    # This time, the value should return immediately instead of regenerate a new one.
    assert_no_difference 'Md5sum.count' do
      assert_equal expected_md5, @test_rpm.md5sum
    end
  end

  test "get sha256 checksum by brew rpm" do
    expected_sha2 = "cf80cd8aed482d5d1527d7dc72fceff84e6326592848447d2dc0b0e87dfc9a90"
    BrewRpm.any_instance.expects(:generate_checksum).once.returns(expected_sha2)
    assert_difference 'Sha256sum.count', 1 do
      sha256sum = @test_rpm.sha256sum
      assert_equal expected_sha2, sha256sum
    end
    # This time, the value should return immediately instead of regenerate a new one.
    assert_no_difference 'Sha256sum.count' do
      assert_equal expected_sha2, @test_rpm.sha256sum
    end
  end

  test "generate checksum in production environment" do
    test_file = Tempfile.new('test_temp_file')
    test_file.write('testing')
    BrewRpm.any_instance.expects('is_production?').twice.returns(true)
    BrewRpm.any_instance.expects('can_access_file?').twice.returns(true)
    File.expects(:open).twice.returns(test_file)

    [Digest::MD5, Digest::SHA256].each do |crypt|
      expected_value = crypt.hexdigest(test_file.read)
      value = @test_rpm.generate_checksum(crypt)
      assert_equal expected_value, value
    end

    test_file.close
  end

  test "generate checksum in production environment with missing file" do
    BrewRpm.any_instance.expects('is_production?').twice.returns(true)
    BrewRpm.any_instance.expects('can_access_file?').twice.returns(false)

    [Digest::MD5, Digest::SHA256].each do |crypt|
      value = @test_rpm.generate_checksum(crypt)
      assert_nil value
    end
  end

  test "generate checksum outside production environment and has no access to brewroot directory" do
    #This should return dummy checksum
    BrewRpm.any_instance.expects('is_production?').twice.returns(false)
    BrewRpm.any_instance.expects('can_access_file?').twice.returns(false)

    assert_match /^fake:[0-9a-f]{27}$/, @test_rpm.generate_checksum(Digest::MD5)
    assert_match /^fake:[0-9a-f]{59}$/, @test_rpm.generate_checksum(Digest::SHA256)
  end

  test "update md5 checksum" do
    expected_md5 = "ae2b1fca515949e5d54fb22b8ed95575"
    new_md5 = Md5sum.create!(:brew_file => @test_rpm,
                            :sig_key => @test_rpm.brew_build.sig_key,
                            :value => 'MD5:1234567')
    assert new_md5.valid?

    BrewRpm.any_instance.expects('can_access_file?').once.returns(true)
    Md5sum.any_instance.expects('checksum_valid?').once.returns(false)
    BrewRpm.any_instance.expects(:generate_checksum).once.returns(expected_md5)
    md5sum = @test_rpm.md5sum
    assert_equal expected_md5, md5sum
  end

  test "update sha256 checksum" do
    expected_sha2 = "cf80cd8aed482d5d1527d7dc72fceff84e6326592848447d2dc0b0e87dfc9a90"
    new_sha2 = Sha256sum.create!(:brew_file => @test_rpm,
                                 :sig_key => @test_rpm.brew_build.sig_key,
                                 :value => 'SHA256:1234567')
    assert new_sha2.valid?

    BrewRpm.any_instance.expects('can_access_file?').once.returns(true)
    Sha256sum.any_instance.expects('checksum_valid?').once.returns(false)
    BrewRpm.any_instance.expects(:generate_checksum).once.returns(expected_sha2)
    sha256sum = @test_rpm.sha256sum
    assert_equal expected_sha2, sha256sum
  end

  test "sign and unsign brew rpm" do
    BrewRpm.any_instance.expects(:generate_checksum).times(4).returns("12345678ABCDEF")
    @test_rpm.mark_as_signed
    @test_rpm.md5sum
    @test_rpm.sha256sum
    assert_equal 1, @test_rpm.is_signed
    assert_equal 1, @test_rpm.has_brew_sigs

    assert_difference ['Md5sum.count', 'Sha256sum.count'], -1 do
      @test_rpm.unsign!
    end

    assert_equal 0, @test_rpm.is_signed
    assert_equal 0, @test_rpm.has_brew_sigs

    # The checksums should be deleted when we unsign the rpm.
    # So calling these again will cause re-generations
    @test_rpm.md5sum
    @test_rpm.sha256sum
  end

  test "rpm is newer" do
    rpms = []
    ['test_rpm-3.1-2', 'test_rpm-3.1-1', 'test_rpm-3.0-1', 'test_rpm-2.0-1'].each do |nvr|
      rpms << create_test_brew_rpm(nvr)
    end
    latest_rpm = rpms.shift
    rpms.each do |rpm|
      assert latest_rpm.is_newer?(rpm)
    end
    # Create a rpm with higher epoch
    assert create_test_brew_rpm(latest_rpm.name, 10).is_newer?(latest_rpm)
  end

  test "rpm is older" do
    rpms = []
    ['test_rpm-2.0-1', 'test_rpm-2.0-2', 'test_rpm-2.1-1', 'test_rpm-3.0-1',].each do |nvr|
      rpms << create_test_brew_rpm(nvr)
    end
    oldest_rpm = rpms.shift
    # Create a rpm with higher epoch
    rpms << create_test_brew_rpm(oldest_rpm.name, 10)
    rpms.each do |rpm|
      assert oldest_rpm.is_older?(rpm)
    end
  end

  test "rpm is equal" do
    rpms = []
    ['test_rpm-2.0-1', 'test_rpm-2.0-1'].each do |nvr|
      rpms << create_test_brew_rpm(nvr)
    end
    assert rpms[0].is_equal?(rpms[1])
  end

  test "compare rpms with invalid brew rpm" do
    rpm = BrewRpm.first
    other_rpm = BrewRpm.last
    targets = [
     [nil, 'Unable to compare package versions because the provided rpm is invalid.'],
     [BrewBuild.first, "Unable to compare package versions because packages #{rpm.name_nonvr} and #{BrewBuild.first.name_nonvr} differ"],
     [other_rpm, "Unable to compare package versions because packages #{rpm.name_nonvr} and #{other_rpm.name_nonvr} differ."],
    ]

    targets.each do |target|
      error = assert_raises(ArgumentError) do
        assert rpm.compare_versions(target[0])
      end
      assert_match /#{target[1]}/, error.message
    end
  end

  test "can't use a duplicate id_brew" do
    other = BrewRpm.last
    rpm = BrewRpm.new(
      :id_brew => other.id_brew,
      :package => Package.first,
      :brew_build => BrewBuild.first,
      :name => 'foo-bar-1.2.3',
      :arch => Arch.last,
      :epoch => '0')
    refute rpm.valid?
    assert_equal ["is already taken (by #{other.id})"], rpm.errors[:id_brew]
  end

  test "can use an id_brew used by an archive" do
    other = BrewArchive.last
    assert_not_nil other.id_brew, 'fixture problem'

    rpm = BrewRpm.new(
      :id_brew => other.id_brew,
      :package => Package.first,
      :brew_build => BrewBuild.first,
      :name => 'foo-bar-1.2.3',
      :arch => Arch.last,
      :epoch => '0')
    assert_valid rpm
  end

  test 'file path changes based on volume name from brew build' do
    build = BrewBuild.first
    build.update_attribute :volume_name, nil
    @test_rpm.update_attribute :brew_build, build
    # default path is used when volume is not given
    assert @test_rpm.file_path.start_with? '/mnt/redhat/brewroot'

    build.update_attribute :volume_name, 'DEFAULT'
    @test_rpm.update_attribute :brew_build, build
    # default path is used when volume name is DEFAULT
    assert @test_rpm.file_path.start_with? '/mnt/redhat/brewroot'

    build.update_attribute :volume_name, 'kernelarchive'
    @test_rpm.update_attribute :brew_build, build
    assert @test_rpm.file_path.start_with? '/mnt/redhat/brewroot/vol/kernelarchive'
  end
end
