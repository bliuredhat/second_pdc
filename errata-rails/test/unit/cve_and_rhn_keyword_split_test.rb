#
# Previously commas were not acceptible delimiters in RHN keywords
# but some users thought they were. Need to strip them out and sanitize
# the keywords.
#
# Also need to do the same for CVEs which also get uniq'ed and sorted.
#
# See Bugs 876058 and 866426
#
require 'test_helper'

class CveAndRhnKeywordsSplitTest < ActiveSupport::TestCase

  def setup
    @rhba = RHBA.find(20836)
    @rhsa = RHSA.find(20292)
  end

  def keyword_test_helper(expected, keywords)
    @rhba.content.update_attribute('keywords', keywords)
    assert_equal expected, Push::Rhn.make_hash_for_push(@rhba, 'mrpush@redhat.com')['keywords']
  end

  def cve_test_helper(expected, cve)
    @rhsa.content.update_attribute('cve', cve)
    assert_equal expected, @rhsa.cve_list
    assert_equal expected.join(' '), @rhsa.cve
    assert_equal expected.join(' '), @rhsa.content.cve
  end

  test "keywords and cves with commas or spaces" do
    expected = ['foo', 'bar', 'baz']
    [
      # Normal
      'foo, bar, baz',
      'foo bar baz',
      # Too many delimiters
      'foo,bar,    baz',
      'foo  bar  baz',
      # Weird edge cases (user has been drinking?)
      ' foo   bar  baz ',
      'foo,   bar   baz, ',
      'foo,,,   bar   baz, ',
      ',foo,   bar,  baz, ',
    ].each do |test_string|
      # Notice the cves get sorted..
      keyword_test_helper(expected, test_string)
      cve_test_helper(expected.sort, test_string)
    end

    # Some real RHN keywords
    keyword_test_helper(['iproute', 'rto_min', 'ipv6'], 'iproute,rto_min,ipv6')
    keyword_test_helper(['iwl100', 'firmware'], 'iwl100 firmware')
    keyword_test_helper(['IPC::Run3', 'perl', 'building', 'dependency', 'Time::HiRes', 'GetOpt::Long'],
      'IPC::Run3, perl, building, dependency, Time::HiRes, GetOpt::Long')

    # Some real-ish CVEs (test the sanitization, the sorting and the uniq'ing)
    expected = ['CVE-2012-4542', 'CVE-2013-1767']
    cve_test_helper(expected, "CVE-2012-4542 CVE-2013-1767")
    cve_test_helper(expected, "   CVE-2013-1767,   CVE-2012-4542,,,")
    cve_test_helper(expected, "CVE-2013-1767  CVE-2012-4542 CVE-2013-1767 ")

    # Try one with no callbacks (tests existing unsantized CVE data)
    @rhsa.content.cve = "   CVE-2013-1767,   CVE-2012-4542,,,"
    assert_equal expected, @rhsa.cve_list

    # Check blank CVE behaviour
    cve_test_helper([], "")
    cve_test_helper([], "   ")
    cve_test_helper([], nil)

  end
end
