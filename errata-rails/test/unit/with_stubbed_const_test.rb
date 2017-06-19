require 'test/unit'
require 'test_helper/with_stubbed_const'

class TestWithStubbedConst < Test::Unit::TestCase
  include WithStubbedConst

  module Bar
    BAZ = 10
  end

  FOO = "foo"

  def test_default_scope
    assert_equal "foo", FOO
    with_stubbed_const(:FOO => "changed!") { assert_equal "changed!", FOO }
    assert_equal "foo", FOO
  end

  def test_specified_scope
    assert_equal 10, Bar::BAZ
    with_stubbed_const({:BAZ => 20}, Bar) { assert_equal 20, Bar::BAZ }
    assert_equal 10, Bar::BAZ
  end

  def test_block_raises
    assert_equal "foo", FOO
    with_stubbed_const(:FOO => 99) { assert_equal 99, FOO; raise "boom" } rescue nil
    assert_equal "foo", FOO
  end

end
