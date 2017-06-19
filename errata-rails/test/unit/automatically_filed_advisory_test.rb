require 'test_helper'

class AutomaticallyFiledAdvisoryTest < ActiveSupport::TestCase
  # For bug 961157
  test "large description limit" do
    # File an advisory with every single bug in rhel 5.7.0
    r = Release.find_by_name 'RHEL-5.7.0'
    b4r = BugsForRelease.new(r)
    pkgs = b4r.eligible_bugs_by_package.keys
    advisory = AutomaticallyFiledAdvisory.new(pkgs.map(&:id), 
                                              { :product => {:id => r.product.id}, 
                                                :release => {:id => r.id},
                                                :type => 'RHBA'
                                              })
    assert_valid advisory
    advisory.save!
    assert_equal "autofs bug fix and enhancement update", advisory.errata.synopsis
    assert_equal "Updated autofs packages that fix several bugs and add various enhancements are now available.", advisory.errata.topic
    assert_equal "autofs bug fix and enhancement update\n\nAutomated description using bugs not possible due to length", advisory.errata.description
  end

  test "RHSA creation" do
    # File an advisory with every single bug in rhel 5.7.0
    r = Release.find_by_name 'RHEL-5.7.0'
    b4r = BugsForRelease.new(r)
    pkgs = b4r.eligible_bugs_by_package.keys
    advisory = AutomaticallyFiledAdvisory.new(pkgs.map(&:id),
                                              { :product => {:id => r.product.id},
                                                :release => {:id => r.id},
                                                :type => 'RHSA'
                                              })
    assert_valid advisory
    advisory.save!
  end
end
