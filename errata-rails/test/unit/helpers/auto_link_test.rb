require 'test_helper'

class AutoLinkTest < ActiveSupport::TestCase

  include ActionView::Helpers # for auto_link and html_escape (synonym for h)
  include ErrataHelper        # for format_comment and errata_convert_links
  include ERB::Util
  #
  # Was having some problems making auto_link work right.
  # See https://bugzilla.redhat.com/show_bug.cgi?id=754048
  #
  # This test helps explain the problem and shows how to solve it.
  # Might as well leave it committed.
  #
  # The problem is that auto_link will escape ampersands that have already
  # been escaped by html_escape (aka h)
  #
  # You can use :sanitize=>false when calling auto_link to prevent this.
  #
  test "auto link basics" do
    link         = "http://foo.com/?bar=10&baz=20"
    link_escaped = "http://foo.com/?bar=10&amp;baz=20"

    # html_escape will escape the & char.
    # (Remember that <%= ... %> now implicitly has a html_escape...)
    assert_equal link_escaped, h(link)

    # Note that the & inside gets escaped. That is correct.
    assert_equal %{<a href="http://foo.com/?bar=10&baz=20">http://foo.com/?bar=10&baz=20</a>}, auto_link(link).html_safe

    # Here is the tricky one:
    # The ampersands in the links get double escaped, firstly by html_escape and secondly by auto_link.
    # Notice that non-link chars are left alone by auto_link.
    problem = "This & that >. See also #{link}"
    expected = "This &amp; that &gt;. See also <a href=\"http://foo.com/?bar=10&amp;baz=20\">http://foo.com/?bar=10&amp;baz=20</a>"
    double_escape_bad = %{This &amp; that &gt;. See also <a href="http://foo.com/?bar=10&amp;baz=20">http://foo.com/?bar=10&amp;baz=20</a>}
    # (notice this double escaping ->------------------------------------------------^^^^^^^^^------------------------------^^^^^^^^^)

    # :( this is no good. (illustrating the problem...)
    assert_equal double_escape_bad, auto_link(h(problem)).html_safe

    # :) this is good. Solution is to pass in :sanitize=>false option to auto_link. \o/
    assert_equal expected, auto_link(h(problem), :sanitize=>false).html_safe # <-- this is good :)
  end

  #
  # Some detective work for Bz 767378
  #
  # errata_convert_links doesn't work when you pass in an
  # ActiveSupport::SafeBuffer instead of a string.
  # Something to do with the gsub probably.
  #
  test "errata_convert_links handles errata links correctly" do


    e1,e2,e3 = Errata.all[-3..-1]
    @errata = e1
    # Plain text is passed through untouched.
    assert_equal "hello there", errata_convert_links("hello there")

    [e1,e2,e3].each do |e|
      @errata = e
      expected_1 = "<a href=\"#{e.id}\" title=\"#{e.synopsis}\">#{e.advisory_name}</a>"
      expected_2 = "<a href=\"#{e.id}\" title=\"#{e.synopsis}\">#{e.shortadvisory}</a>"

      # advisory_name is like this: RHSA-2011:12294
      # shortadvisory is like this: 2011:12294
      assert_equal expected_1, errata_convert_links(e.advisory_name)
      assert_equal expected_2, errata_convert_links(e.shortadvisory)

      # I've put in a hack/workaround to fix this weird html safe problem.
      # See errata_convert_links in errata_helper.
      # These used to fail...
      assert_equal expected_1, errata_convert_links(e.advisory_name.html_safe)
      assert_equal expected_2, errata_convert_links(e.shortadvisory.html_safe)
    end

    #
    # An example based on jwl's bug report.
    #
    input = "packages in #{e1.shortadvisory}, #{e2.shortadvisory}, #{e3.shortadvisory} should"
    expected =
      "packages in " +
      "<a href=\"#{e1.id}\" title=\"#{e1.synopsis}\">#{e1.shortadvisory}</a>, " +
      "<a href=\"#{e2.id}\" title=\"#{e2.synopsis}\">#{e2.shortadvisory}</a>, " +
      "<a href=\"#{e3.id}\" title=\"#{e3.synopsis}\">#{e3.shortadvisory}</a> " +
      "should"

    assert_equal expected, errata_convert_links(input)
    assert_equal expected, errata_convert_links(input.html_safe)

    # format_comment is actually what gets called from our templates
    assert_equal expected, format_comment(input)
  end

  test "errata_convert_links handles bz links correctly" do

    @bugs_by_id = []
    b1,b2 = Bug.active.last(2)
    [b1,b2].each do |bug|
      input = "Pls refer to bug #{bug.id}"
      expected = "Pls refer to <a href=\"#{bug.url}\" title=\"#{h bug.bug_status} - #{h bug.short_desc}\">bug #{bug.id}</a>"

      # ensure 'whatever bug <bug id>' replaced with 'whatever bug <bug link>'
      assert_equal expected, errata_convert_links(input)
    end

    b3 = Bug.where(:bug_status => "CLOSED").last
    input = "Pls refer to bz #{b3.id}"
    text = "Pls refer to <s><a href=\"%s\" title=\"%s - %s\">%s</a></s>"
    expected = text % [b3.url, b3.bug_status, b3.short_desc, "bz #{b3.id}"]

    # ensure output is like 'whatever <s><bug link></s>' when bug status is 'CLOSED'
    assert_equal expected, errata_convert_links(input)

    # ensure bug link to specific comment
    input += " comment #2"
    expected = text % ["#{b3.url}#c2", b3.bug_status, b3.short_desc, "bz #{b3.id} comment #2"]
    assert_equal expected, errata_convert_links(input)

    # virify output via format_comment
    assert_equal expected, format_comment(input)

  end

  test "errata_convert_links handles JIRA links correctly" do

    # Necessary for errata_convert_links to work
    @errata = Errata.first

    # Open JIRA issues
    JiraIssue.where('status != ?', Settings.jira_closed_status).first(2).each do |jira|
      input    = "Here is a link to JIRA issue #{jira.key}."
      expected = "Here is a link to JIRA issue <a href=\"#{jira.url}\">#{jira.key}</a>."
      assert_equal expected, errata_convert_links(input)

      input    = "What about Jira Task #{jira.key}?"
      expected = "What about Jira Task <a href=\"#{jira.url}\">#{jira.key}</a>?"
      assert_equal expected, errata_convert_links(input)

      input    = "Plain old JIRA #{jira.key} should also work"
      expected = "Plain old JIRA <a href=\"#{jira.url}\">#{jira.key}</a> should also work"
      assert_equal expected, errata_convert_links(input)
    end

    # Closed JIRA issues enclosed by <s> tag
    JiraIssue.where(:status => Settings.jira_closed_status).first(2).each do |jira|
      input    = "Jira issue #{jira.key} is closed."
      expected = "Jira issue <s><a href=\"#{jira.url}\">#{jira.key}</a></s> is closed."
      assert_equal expected, errata_convert_links(input)
    end

    # JIRA with key starting with TASK should work
    jira = JiraIssue.find_by_key!('TASKOTRON-1234');
    input    = "JIRA #{jira.key} has a tricky key"
    expected = "JIRA <a href=\"#{jira.url}\">#{jira.key}</a> has a tricky key"
    assert_equal expected, errata_convert_links(input)

    # JIRA with non-default project key format
    jira = JiraIssue.find_by_key!('ABC_2-1234');
    input    = "JIRA #{jira.key} should be OK too!"
    expected = "JIRA <a href=\"#{jira.url}\">#{jira.key}</a> should be OK too!"
    assert_equal expected, errata_convert_links(input)

    # Not-existent JIRA issues are ignored
    input = 'The Jira issue FOOBAR-12345 does not exist!'
    assert_equal input, errata_convert_links(input)
  end

end
