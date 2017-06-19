require 'test_helper'

class FtpTest < ActiveSupport::TestCase
  def ftp_dir_test(expected, variant_or_name, arch_or_name, opts={})
    arch = arch_or_name.kind_of?(String) ? Arch.find_by_name!(arch_or_name) : arch_or_name
    variant = variant_or_name.kind_of?(String) ? Variant.find_by_name!(variant_or_name) : variant_or_name

    rpm_filter = opts[:rpm_filter] || lambda{|*args| true}
    rpm = BrewRpm.where(:arch_id => arch).find(&rpm_filter)
    assert_not_nil rpm, 'testdata problem: no RPMs available for the given arch & filter!'

    dir = Push::Ftp.get_ftp_dir(rpm, variant, arch)
    assert_equal expected, dir
  end

  test 'ftp dir is based on RHEL variant and arch' do
    ftp_dir_test '/ftp/pub/redhat/linux/enterprise/7Workstation/en/os/ppc64/', '7Workstation-7.0.Z', 'ppc64'
  end

  test 'ftp dir includes SRPMS for source RPMs' do
    # Source RPMs simply belong to an arch of name SRPMS, so you'd expect
    # the same code to be used here as in the above test.
    # However, get_ftp_dir has a specific code path for is_srpm? for some reason.
    # Test it just in case.
    ftp_dir_test '/ftp/pub/redhat/linux/enterprise/7Workstation/en/os/SRPMS/', '7Workstation-7.0.Z', 'SRPMS',
      :rpm_filter => lambda{|rpm| rpm.is_srpm?}
  end

  test 'debuginfo path is added to ftp dir for debuginfo rpm' do
    ftp_dir_test '/ftp/pub/redhat/linux/enterprise/7Workstation/en/os/ppc64/Debuginfo/', '7Workstation-7.0.Z', 'ppc64',
      :rpm_filter => lambda{|rpm| rpm.is_debuginfo?}
  end

  # bug 1121937
  test 'only the variant name up to the first dash is included in ftp dir' do
    v = Variant.find_by_name!('7Workstation-7.0.Z')
    v.rhel_variant.update_attribute(:name, '9Foo-Bar-Baz.quux-1.2')
    ftp_dir_test '/ftp/pub/redhat/linux/enterprise/9Foo/en/os/x86_64/', v, 'x86_64'
  end
end
