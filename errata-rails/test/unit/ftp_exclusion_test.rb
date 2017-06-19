require 'test_helper'
require 'push/ftp'

class FtpExclusionTest < ActiveSupport::TestCase
  fixtures :ftp_exclusions

  test "RHEL Release -debuginfo exclusion" do
    
    maps = ErrataBrewMapping.find :all
    
    forbid, allow = maps.partition { |m| Push::Ftp.exclude_debuginfo?(m) }
    # expect there should be some of each
    assert forbid.length > 0
    assert allow.length > 0
    
    exclude_rhel = RhelRelease.all.select(&:exclude_ftp_debuginfo?)
    using_exclude_debuginfo_rhel = lambda{|m| exclude_rhel.include?(m.product_version.rhel_release)}
    # no allowed mappings should be using any RHEL with excluded debuginfo
    assert allow.select(&using_exclude_debuginfo_rhel).empty?
    # all forbidden mappings should be using a RHEL with excluded debuginfo
    assert forbid.reject(&using_exclude_debuginfo_rhel).empty?
  end
end
