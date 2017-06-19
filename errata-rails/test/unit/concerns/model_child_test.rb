require 'test_helper'

class ModelChildTest < ActiveSupport::TestCase
  test "get class" do
    channel = ModelChild.get_class("Channel")
    assert_equal Channel, channel
  end

  test "get class with empty argument should fail" do
    error = assert_raise(ArgumentError) do
      ModelChild.get_class("")
    end
    assert_equal "Missing type.", error.message
  end

  test "call sub class" do
    child_class = FakeParent.child_get("FakeChild")
    assert_equal FakeChild, child_class
  end

  test "call invalid sub class should fail" do
    error = assert_raise(NameError) do
      child_class = FakeParent.child_get("NotChild")
    end
    assert_equal "NotChild is not a valid type.", error.message
  end
end

class FakeParent
  include ModelChild
end

class FakeChild < FakeParent
end

class NotChild
end