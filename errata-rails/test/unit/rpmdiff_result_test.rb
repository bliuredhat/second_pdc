require 'test_helper'

class RpmdiffResultTest < ActiveSupport::TestCase
  test "waivable" do
    have_waivable = false
    have_unwaivable = false

    RpmdiffResult.waivable.each do |r|
      assert r.waivable?, "#{r.inspect} is returned by waivable scope but is not waivable?"
      have_waivable = true
    end

    RpmdiffResult.where('result_id not in (?)', RpmdiffResult.waivable).each do |r|
      refute r.waivable?, "#{r.inspect} is not returned by waivable scope but is waivable?"
      have_unwaivable = true
    end

    assert have_waivable, 'precondition failed: need at least one waivable result'
    assert have_unwaivable, 'precondition failed: need at least one unwaivable result'
  end
end
