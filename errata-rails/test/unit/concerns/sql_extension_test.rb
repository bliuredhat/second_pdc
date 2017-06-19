require 'test_helper'

class SqlExtensionTest < ActiveSupport::TestCase
  def create_test_released_package(rpm_name)
    ReleasedPackage.create!(
      :arch => Arch.first,
      :brew_build => BrewBuild.first,
      :brew_rpm => BrewRpm.first,
      :package => Package.first,
      :version_id => Variant.first.id,
      :product_version => ProductVersion.first,
      :rpm_name => rpm_name,
      :full_path => "/mnt/redhat/brewroot/packages/#{rpm_name}.rpm")
  end

  test "regex_where with invalid argument type" do
    error = assert_raises(ArgumentError) do
      # I use ReleasedPackage here as I don't have to
      # include the concern module here.
      ReleasedPackage.regex_where("id regexp /test/")
    end
    assert_match(/regex_where requires a hash as argument/, error.message)
  end

  test "regex_where with nil value for field" do
    error = assert_raises(ArgumentError) do
      ReleasedPackage.regex_where({:variant => nil})
    end
    assert_match(/Field value can't be nil/, error.message)
  end

  test "regex_where raise not implement error" do
    ReleasedPackage.stubs(:sql_adapter).returns(:Oracle)

    error = assert_raises(NotImplementedError) do
      ReleasedPackage.regex_where(:brew_rpm_id => BrewRpm.first)
    end
    assert_match(/regex_where is only supported for Mysql currently/, error.message)
  end

  test "regex_where returns match values" do
    expected_rpms = ['test_package_1', 'test_package_2']
    ['other_test_package_1', 'another_test_package_1'].concat(expected_rpms).each do |rpm_name|
      create_test_released_package(rpm_name)
    end

    results = ReleasedPackage.regex_where(:full_path => "/brewroot/packages/test_package_[12]\\.rpm$")

    assert_equal 2, results.count
    expected_rpms.each do |rpm_name|
      results.map(&:rpm_name).include?(rpm_name)
    end
  end
end
