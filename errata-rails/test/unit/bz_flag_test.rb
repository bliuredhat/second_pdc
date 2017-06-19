require 'test_helper'

class BzFlagTest < ActiveSupport::TestCase

  test "BzFlag::Flag initialize" do
    foo = BzFlag::Flag.new("foo+")
    bar = BzFlag::Flag.new("bar-")
    baz = BzFlag::Flag.new("baz?")

    assert_equal ["foo", BzFlag::ACKED],    [foo.name, foo.state]
    assert_equal ["bar", BzFlag::NACKED],   [bar.name, bar.state]
    assert_equal ["baz", BzFlag::PROPOSED], [baz.name, baz.state]

    # Whitespace (and Comparable methods) test
    assert_equal     BzFlag::Flag.new(' foo+  '), BzFlag::Flag.new('foo+')
    assert_not_equal BzFlag::Flag.new('boo+'),    BzFlag::Flag.new('foo+')
    assert_not_equal BzFlag::Flag.new('foo+'),    BzFlag::Flag.new('foo?')
  end

  test "BzFlag::Flag css class" do
    assert_match /acked$/, BzFlag::Flag.new('boo+').css_class
    assert_match /proposed$/, BzFlag::Flag.new('boo?').css_class
  end

  test "BzFlag::Flag invalid" do
    # Test that parsing fails correctly
    inv1 = BzFlag::Flag.new("qux/")
    assert_equal inv1.state, BzFlag::INVALID
    assert_equal inv1.name,  "qux/"

    assert_equal BzFlag::Flag.new(" frb + ").state, BzFlag::INVALID
  end

  test "BzFlag::Flag to string" do
    foo = BzFlag::Flag.new("foo+")

    # Test that to_s works
    assert_equal "foo+", foo.to_s
    assert_equal "foo+", "#{foo}"
  end

  test "BzFlag::Flag comparison" do
    foo = BzFlag::Flag.new("foo+")
    bar = BzFlag::Flag.new("bar-")

    assert_equal foo, BzFlag::Flag.new("foo+")
    assert_not_equal foo, bar
  end

  test "BzFlag::FlagList stuff" do
    flags = BzFlag::FlagList.new("foo+, boo+, bar-, baz?")

    # has_flag? means "has acked flag"
    assert flags.has_flag?('foo')
    assert flags.has_flag?('boo')
    refute flags.has_flag?('bar')
    refute flags.has_flag?('baz')
    refute flags.has_flag?('qux')

    assert flags.find_flag('bar',BzFlag::NACKED)
    refute flags.find_flag('foo',BzFlag::NACKED)

    # Test flag_state
    assert_equal BzFlag::PROPOSED, flags.flag_state('baz')
    assert_equal BzFlag::ACKED,    flags.flag_state('foo')
    assert_equal BzFlag::NACKED,   flags.flag_state('bar')

    # When it's not there nil is returned
    assert_nil flags.flag_state('qux')

    # Test to_s
    assert "foo+, bar-, baz?", flags.to_s

    # Enumerable methods
    assert_equal "foo-boo-bar-baz", flags.map{ |f| f.name }.join('-')
    assert_equal %w[bar baz], flags.select{ |f| f.name =~ /ba/ }.map{ |f| f.name }

    # has_all_flags?
    assert flags.has_all_flags?(['foo'])
    assert flags.has_all_flags?(['boo'])
    assert flags.has_all_flags?(['foo','boo'])
    refute flags.has_all_flags?(['foo','bar'])
    refute flags.has_all_flags?(['foo','baz'])
  end

  test "FlagList parsing failure" do
    # Parsing failure
    assert BzFlag::FlagList.new("foo+ qux/").has_invalid_flag?
    assert BzFlag::FlagList.new("foo+ qux-").has_invalid_flag?
    refute BzFlag::FlagList.new("foo+, qux-").has_invalid_flag?
  end

  #
  # See also test_bz_flag_methods in test/unit/bug_test
  #
end
