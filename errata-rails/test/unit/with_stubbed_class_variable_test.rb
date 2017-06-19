require 'test/unit'
require 'test_helper/with_stubbed_class_variable'

class TestWithStubbedClassVariable < Test::Unit::TestCase
  include WithStubbedClassVariable

  class TestClass
    def self.get_foo
      @@foo ||= 10
    end

    def self.get_bar
      @@bar
    end
  end

  def test_stubbed_class_variable
    assert_equal 10, TestClass::get_foo
    with_stubbed_class_variable({:@@foo => 20}, TestClass) { assert_equal 20, TestClass::get_foo }
    assert_equal 10, TestClass::get_foo
  end

  def test_block_raises
    assert_equal 10, TestClass::get_foo
    with_stubbed_class_variable({:@@foo => 99}, TestClass) { assert_equal 99, TestClass::get_foo; raise "boom" } rescue nil
    assert_equal 10, TestClass::get_foo
  end

  def test_undefined_variable
    assert !TestClass.class_variable_defined?(:@@bar)
    with_stubbed_class_variable({:@@bar => 42}, TestClass) { assert_equal 42, TestClass::get_bar }
    assert !TestClass.class_variable_defined?(:@@bar)
  end
end
