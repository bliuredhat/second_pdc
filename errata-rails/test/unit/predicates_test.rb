require 'test_helper'

class PredicatesTest < ActiveSupport::TestCase
  test 'and nothing returns true' do
    assert Predicates.and().call()
    assert Predicates.and().call('whatever', 'arguments')
  end

  test 'and requires all passed predicates to be true' do
    pred = Predicates.and(
      lambda{|n| n%5 == 0},
      # nil should be ignored
      nil,
      lambda{|n| n%3 == 0})
    refute pred.call(5)
    refute pred.call(10)
    refute pred.call(3)
    refute pred.call(6)
    assert pred.call(15)
    assert pred.call(30)
  end

  test 'and short-circuits as expected' do
    first_called = false
    last_called = false
    pred = Predicates.and(
      lambda{|*args| first_called = true; true },
      lambda{|*args| false },
      lambda{|*args| last_called = true; true })

    refute pred.call()
    assert first_called
    refute last_called
  end

  test 'true is true' do
    assert Predicates.true().call()
    assert Predicates.true().call(%w[a b c d])
  end
end
