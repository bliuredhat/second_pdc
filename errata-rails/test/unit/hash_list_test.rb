require 'test_helper'

class HashListTest < ActiveSupport::TestCase

  def assert_merge_correct(methods, merge_this, expected)
    Array.wrap(methods).each do |method|
      hash_list = HashList.new
      hash_list[:a] = %w[foo bar]
      assert_equal(expected, hash_list.send(method, merge_this))
      assert_equal(expected, hash_list)
    end
  end

  test "merging" do
    assert_merge_correct(
      [:list_merge!, :list_merge_uniq!],
      { :b => %w[baz quux] },
      { :a => %w[foo bar], :b => %w[baz quux] }
    )

    assert_merge_correct(
      [:list_merge!, :list_merge_uniq!],
      { :a => %w[baz quux] },
      { :a => %w[foo bar baz quux] }
    )

    assert_merge_correct(
      [:list_merge!, :list_merge_uniq!],
      { :a => 'baz' },
      { :a => %w[foo bar baz] }
    )

    assert_merge_correct(
      :list_merge!,
      { :a => [10, 10, 11, 23, 'foo'], :b => %w[baz baz quux], 'blah' => 123 },
      { :a => ['foo', 'bar', 10, 10, 11, 23, 'foo'], :b => %w[baz baz quux], 'blah' => [123] }
    )
  end

  test "uniq merging" do
    assert_merge_correct(
      :list_merge_uniq!,
      { :a => %w[foo baz] },
      { :a => %w[foo bar baz] }
    )

    assert_merge_correct(
      :list_merge_uniq!,
      { :a => ['foo'], :b => [1,2,1,2,1,2,2,2,2,3], 'blah' => 123 },
      { :a => ['foo', 'bar'], :b => [1,2,3], 'blah' => [123] }
    )
  end

end
