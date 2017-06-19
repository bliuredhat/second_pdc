#
# See ./lib/text_with_classification_links.rb
#
require 'test_helper'

class TextWithImpactLinkTest < ActiveSupport::TestCase
  test "it works" do
    T = TextWithImpactLink

    link1 = "https://access.redhat.com/security/updates/classification/#moderate"
    link2 = "https://access.redhat.com/security/updates/classification/#critical"
    text = T.new "hello\n#{link1}\ngood bye"

    assert_equal "hello\ngood bye", text.strip_links
    assert text.has_link?
    assert text.has_link?('Moderate')
    assert_equal link1, text.links.first

    text = T.new "foo bar\nbaz"
    assert !text.has_link?
    assert text.links.empty?

    # (Actually should not be able to have more than one link in real life).
    text = T.new "aa #{link1}\n#{link2} zz"
    assert text.has_link?
    assert_equal 2, text.links.length
    assert_equal link1, text.links.first
    assert_equal link2, text.links.last
    assert_equal "aa zz", text.strip_links

    assert_equal String, text.to_s.class
    assert_equal String, text.strip_links.to_s.class

    text = T.new ""
    assert_equal "#{link1}\n", text.ensure_link('Moderate')
    assert_equal "#{link2}\n", text.ensure_link('Critical')
    assert_equal "#{link2}\n", text.ensure_link('Important').ensure_link('Critical')
    assert_equal "#{link2}\n", text.ensure_link('Important').ensure_link('Low').ensure_link('Critical')
    assert_raise(RuntimeError) { text.ensure_link('Bogus') }

    assert_equal T, text.class
    assert_equal T, text.strip_links.class
    assert_equal String, text.to_s.class
    assert_equal String, text.strip_links.to_s.class
    assert_equal String, T.new.to_s.class
    assert_equal '', T.new.to_s

    # Want to be able to take a nil without choking
    # (String can't do that)
    assert_equal '', T.new(nil).to_s
    assert_equal String, T.new(nil).to_s.class
  end
end
