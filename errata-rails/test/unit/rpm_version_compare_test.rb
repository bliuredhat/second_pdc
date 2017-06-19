require 'test_helper'

class RpmVersionCompareTest < ActiveSupport::TestCase
  setup do
    @arch = Arch.find_by_name('x86_64')
    @build = BrewBuild.first
    @package = @build.package
    @method_maps = {"-1" => "is_older?", "1" => "is_newer?", "0" => "is_equal?"}
  end

  def get_rpm(nevr)
    if ( nevr =~ /^(.*)-([^-]+)-([^-]+)-([^-]+)$/ )
      return BrewRpm.create!(
        :id_brew => BrewRpm.pluck('max(id_brew)').first + 100,
        :name => "#{$1}-#{$3}-#{$4}",
        :epoch => $2,
        :arch => @arch,
        :brew_build => @build,
        :package => @package)
    else
      raise ArgumentError, 'Invalid nevr #{nevr}'
    end
  end

  def assert_rpm_compare(test_case)
    rpm_1 = get_rpm(test_case[:rpm_1])
    rpm_2 = get_rpm(test_case[:rpm_2])
    result = test_case[:result]
    invert_result = result * -1

    message = "comparing #{rpm_1.try(:name)} <=> #{rpm_2.try(:name)}"

    assert_equal result, rpm_1.compare_versions(rpm_2), message
    assert_equal invert_result, rpm_2.compare_versions(rpm_1), message
    assert rpm_1.send(@method_maps[result.to_s], rpm_2), message
    assert rpm_2.send(@method_maps[invert_result.to_s], rpm_1), message
  end

  test "compare not rpm should fail" do
    rpm_1 = BrewRpm.first
    rpm_2 = Bug.first

    error = assert_raises(ArgumentError) do
      rpm_1.compare_versions(rpm_2)
    end
    assert_equal "Unable to compare package versions because the provided rpm is invalid.", error.message
  end

  test "compare two rpms with different name should fail" do
    rpm_1 = BrewRpm.first
    rpm_2 = BrewRpm.last

    error = assert_raises(ArgumentError) do
      rpm_1.compare_versions(rpm_2)
    end
    assert_equal "Unable to compare package versions because packages #{rpm_1.name_nonvr} and #{rpm_2.name_nonvr} differ.", error.message
  end

  test "compare two rpms with same package but different name_nonvr should fail" do
    error = assert_raises(ArgumentError) do
      assert_rpm_compare(:rpm_1 =>  "qpid-qmf-devel-1-1-1", :rpm_2 =>  "qpid-qmf-debuginfo-1-1-1", :result => 0)
    end
    assert_equal "Unable to compare package versions because packages qpid-qmf-devel and qpid-qmf-debuginfo differ.", error.message
  end

  test "compare rpms with alpha characters" do
    test_cases = [
     { :rpm_1 => 'cipe-0-1.4snap-1',    :rpm_2 => 'cipe-0-1.4.5-1',        :result => -1 },
     { :rpm_1 => 'cipe-0-1.4snap-1',    :rpm_2 => 'cipe-0-1.4snap-2',      :result => -1 },
     { :rpm_1 => 'textutils-0-2.0e-6',  :rpm_2 => 'textutils-0-2.0e-8',    :result => -1 },
     { :rpm_1 => 'textutils-0-2.0e-8',  :rpm_2 => 'textutils-0-2.0.11-7',  :result => -1 },
     { :rpm_1 => 'hanterm-xf-0-p19-15', :rpm_2 => 'hanterm-xf-0-2.0.0-6',  :result => -1 },
     { :rpm_1 => 'hanterm-xf-0-p19-15', :rpm_2 => 'hanterm-xf-0-p19-15',   :result => 0 },
    ]

    test_cases.each do |test_case|
      assert_rpm_compare(test_case)
    end
  end

  test "compare epoches" do
   test_cases = [
     { :rpm_1 => 'cipe-5-1.4-1',        :rpm_2 => 'cipe-5-1.4-1',        :result => 0 },
     { :rpm_1 => 'cipe-5-1.4-1',        :rpm_2 => 'cipe-10-1.4-1',       :result => -1 },
     { :rpm_1 => 'textutils-5-3.0-10',  :rpm_2 => 'textutils-10-2.0-8',  :result => -1 },
     { :rpm_1 => 'textutils-10-2.0-8',  :rpm_2 => 'textutils-10-3.0-10', :result => -1 },
    ]

    test_cases.each do |test_case|
      assert_rpm_compare(test_case)
    end
  end

  test "compare versions" do
    test_cases = [
     { :rpm_1 => 'cipe-0-1.4-1',        :rpm_2 => 'cipe-0-1.41-1',       :result => -1 },
     { :rpm_1 => 'cipe-0-1.41-1',       :rpm_2 => 'cipe-0-1.45-1',       :result => -1 },
     { :rpm_1 => 'textutils-0-2.0-1',   :rpm_2 => 'textutils-0-2.1-1',   :result => -1 },
     { :rpm_1 => 'textutils-0-2.0.0-1', :rpm_2 => 'textutils-0-2.0.1-1', :result => -1 },
     { :rpm_1 => 'hanterm-xf-0-20.0.1-15', :rpm_2 => 'hanterm-xf-0-20.0.1-15', :result => 0 },
    ]

    test_cases.each do |test_case|
      assert_rpm_compare(test_case)
    end
  end

  test "compare releases" do
    test_cases = [
     { :rpm_1 => 'foo-0-1.0-1.f20',                    :rpm_2 => 'foo-0-1.0-1.f20',                    :result => 0 },
     { :rpm_1 => 'foo-0-1.0-1.f20',                    :rpm_2 => 'foo-0-1.0-1.f21',                    :result => -1 },
     { :rpm_1 => 'ruby-shadow-0-1.4.1-13.el6',         :rpm_2 => 'ruby-shadow-0-1.4.1-13.el6_4',       :result => -1 },
     { :rpm_1 => 'openssl-devel-0-1.0.1e-16.el6_5.8',  :rpm_2 => 'openssl-devel-0-1.0.1e-16.el6_5.9',  :result => -1 },
     { :rpm_1 => 'rubygem-aeolus-cli-0-0.3.3-1.el6_3', :rpm_2 => 'rubygem-aeolus-cli-0-0.3.3-1.el6_4', :result => -1 },
     { :rpm_1 => 'rubygem-aeolus-cli-0.7.7-1.el6cf',   :rpm_2 => 'rubygem-aeolus-cli-0.7.7-1.el6_1',   :result => -1 },
     { :rpm_1 => 'rubygem-aeolus-cli-0-0.7.7-1.el6cf', :rpm_2 => 'rubygem-aeolus-cli-0-0.7.7-1.el7',   :result => -1 },
    ]

    test_cases.each do |test_case|
      assert_rpm_compare(test_case)
    end
  end

  # Specially treat the comparison between 'el' and 'ael',
  # otherwise, do normal comparison.
  # Bug: 1378728
  test 'special_cmp' do
    test_cases = [
      # return 'el' > 'ael' ? -1 : 1
      [ 'el', 'ael', -1], ['ael',  'el',  1],
      [ 'el',  'el',  0], ['ael', 'ael',  0],
      ['foo',  'el',  1], ['ael', 'bar', -1],
      [  nil,   nil,  0], ['foo', 'bar',  1],
    ]

    test_cases.each do |a, b, expected|
      assert_equal expected, RpmVersionCompare.special_cmp(a, b), "'#{a}' <=> '#{b}'"
    end
  end

  # Bug 1118521
  test "compare versions of differing length" do
    test_cases = [
     { :rpm_1 => 'openstack-neutron-0-2014.1-35.el7ost',  :rpm_2 => 'openstack-neutron-0-2014.1.1-2.el7ost', :result => -1 },
     { :rpm_1 => 'openstack-neutron-0-2014.1.1-2.el7ost', :rpm_2 => 'openstack-neutron-0-2014.1-2.el7ost',   :result =>  1 },
     { :rpm_1 => 'openstack-neutron-0-2014.1-2.el7ost',   :rpm_2 => 'openstack-neutron-0-2014.1.2-el7ost',   :result => -1 },
    ]

    test_cases.each do |test_case|
      assert_rpm_compare(test_case)
    end
  end

  test 'find newest nvrs' do
    newest_virt = 'virt-p2v-1.32.5-5.el7'
    newest_samba = 'samba-4.2.10-7.el7_2'
    newest_php = 'php-5.4.16-40.el7'
    notexist_builds = 'notexist-bla-1.2.3'
    bad_builds = 'bad-format'
    nvrs = ["virt-p2v-1.32.5-2.el7",
            "virt-p2v-1.32.5-4.el7",
            "php-5.4.16-36.3.el7_2",
            "php-5.4.16-36.1.el7_2.1",
            newest_samba,
            newest_virt,
            newest_php,
            notexist_builds,
            bad_builds
           ]
    result = RpmVersionCompare.find_newest_nvrs(nvrs)
    # returns all the newest builds and does nothing.
    assert_array_equal [newest_virt,
                        newest_samba,
                        newest_php,
                        notexist_builds,
                        bad_builds],
                       result
  end
end
