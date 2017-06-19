require 'test_helper'

class DisplayListWithAndTest < ActiveSupport::TestCase
  include ApplicationHelper

  test "display_list_with_and works as expected" do

    foo_bar_baz = %w[foo bar baz]
    bar_baz     = %w[bar baz]
    baz         = %w[baz]
    empty       = []
    quite_long  = %w[a b c def ghi jkl lmn opq]

    assert_equal "foo, bar and baz",    display_list_with_and(foo_bar_baz)
    assert_equal "foo, bar, and baz",   display_list_with_and(foo_bar_baz, :oxford_comma=>true)
    assert_equal "foo, bar & baz",      display_list_with_and(foo_bar_baz, :ampersand=>true)
    assert_equal "foo, bar, & baz",     display_list_with_and(foo_bar_baz, :ampersand=>true, :oxford_comma=>true)
    assert_equal "foo, bar or baz",     display_list_with_and(foo_bar_baz, :and=>'or')
    assert_equal "foo, bar, or baz",    display_list_with_and(foo_bar_baz, :and=>'or', :oxford_comma=>true)

    assert_equal "bar and baz",    display_list_with_and(bar_baz)
    assert_equal "bar, and baz",   display_list_with_and(bar_baz, :oxford_comma=>true)
    assert_equal "bar & baz",      display_list_with_and(bar_baz, :ampersand=>true)
    assert_equal "bar, & baz",     display_list_with_and(bar_baz, :ampersand=>true, :oxford_comma=>true)
    assert_equal "bar or baz",     display_list_with_and(bar_baz, :and=>'or')
    assert_equal "bar, or baz",    display_list_with_and(bar_baz, :and=>'or', :oxford_comma=>true)

    assert_equal "baz", display_list_with_and(baz)
    assert_equal "baz", display_list_with_and(baz, :oxford_comma=>true)
    assert_equal "baz", display_list_with_and(baz, :ampersand=>true)
    assert_equal "baz", display_list_with_and(baz, :ampersand=>true, :oxford_comma=>true)
    assert_equal "baz", display_list_with_and(baz, :and=>'or')
    assert_equal "baz", display_list_with_and(baz, :and=>'or', :oxford_comma=>true)

    assert_equal "", display_list_with_and(empty)
    assert_equal "", display_list_with_and(empty, :oxford_comma=>true)
    assert_equal "", display_list_with_and(empty, :ampersand=>true)
    assert_equal "", display_list_with_and(empty, :ampersand=>true, :oxford_comma=>true)
    assert_equal "", display_list_with_and(empty, :and=>'or')
    assert_equal "", display_list_with_and(empty, :and=>'or', :oxford_comma=>true)

    assert_equal "a, b, c, def, ghi, jkl, lmn and opq", display_list_with_and(quite_long)
    assert_equal "a, b, c, def, ghi, jkl, lmn, and, last but not least, opq", display_list_with_and(quite_long, :and=>'and, last but not least,', :oxford_comma=>true)

    # don't do this, but :ampersand=>true trumps :and=>'...'
    assert_equal "foo, bar & baz",  display_list_with_and(foo_bar_baz, :and=>'or', :ampersand=>true)
  end

  test 'elide_after' do
    assert_equal 'a, b, c, d and e',      display_list_with_and(%w[a b c d e], :elide_after => 6)
    assert_equal 'a, b, c, d and e',      display_list_with_and(%w[a b c d e], :elide_after => 5)
    assert_equal 'a, b, c, d and 1 more', display_list_with_and(%w[a b c d e], :elide_after => 4)
    assert_equal 'a, b, c and 2 more',    display_list_with_and(%w[a b c d e], :elide_after => 3)
    assert_equal 'a, b and 3 more',       display_list_with_and(%w[a b c d e], :elide_after => 2)
    assert_equal 'a and 4 more',          display_list_with_and(%w[a b c d e], :elide_after => 1)
    assert_equal 'a, b, c, d and e',      display_list_with_and(%w[a b c d e], :elide_after => 0)
    assert_equal 'a, b, c, d and e',      display_list_with_and(%w[a b c d e], :elide_after => -1)
  end
end
