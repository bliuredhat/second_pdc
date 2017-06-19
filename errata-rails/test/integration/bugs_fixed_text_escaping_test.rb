require 'test_helper'

class BugsFixedTextEscapingTest < ActionDispatch::IntegrationTest

  #
  # See bug 773071
  #
  test "bugs fixed text should not escape html chars" do
    # Find a bug that has a < char in its name and is filed in an errata
    bug = Bug.where("short_desc like '%<%'").find{|bug|bug.errata.any?}
    errata = bug.errata.first # Gah, confusing (non-)plurals!

    # Now test the behaviour
    auth_as admin_user
    visit "/errata/show_text/#{errata.id}"

    # It's supposed to be plain text (hence the escaping issues), so let's test that I guess.
    assert_match %r|text/plain|, page.response_headers["Content-Type"]

    # Not using page.has_content? since that actually expects the < chars to be escaped...
    # (Also must use page.source not page.html since page.html will lowercase things that look like html tags, eg <FOO> becomes <foo>...)
    assert_match %r|#{Regexp.escape(bug.short_desc)}|, page.source # will fail if the < char is escaped
  end
end
