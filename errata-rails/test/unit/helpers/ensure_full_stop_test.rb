require 'test_helper'

class DisplayListWithAndTest < ActiveSupport::TestCase
  include ApplicationHelper
  include ActionView::Helpers::SanitizeHelper

  def ensure_full_stop(val)
    val.full_stop
  end

  test "ensure_full_stop works as expected" do

    assert_equal "foo.", ensure_full_stop("foo")
    assert_equal "foo.", ensure_full_stop("foo.")
    assert_equal "foo.", ensure_full_stop("foo  ")
    assert_equal "foo.", ensure_full_stop("foo.  ")

    assert_equal "foo?", ensure_full_stop("foo?")
    assert_equal "foo!", ensure_full_stop("foo!")

    assert_equal "One thing. Another thing.", ensure_full_stop("One thing. Another thing")
    assert_equal "One thing. Another thing.", ensure_full_stop("One thing. Another thing.")

    # It doesn't do anything if it looks like there's an html tag at the very end..
    assert_equal "<ul><li>foo</li></ul>", ensure_full_stop("<ul><li>foo</li></ul>")
    # But it will do this kind of thing..
    assert_equal "<b>bold</b> foo.", ensure_full_stop("<b>bold</b> foo")

  end

end
