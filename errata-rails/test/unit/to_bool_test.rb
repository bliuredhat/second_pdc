require 'test_helper'

class ToBoolTest < ActiveSupport::TestCase
  test 'true' do
    assert 1.to_bool
    assert 42.to_bool
    assert -1.to_bool

    assert '1'.to_bool
    assert '42'.to_bool
    assert '-1'.to_bool

    assert true.to_bool
  end

  test 'false' do
    refute 0.to_bool

    refute '0'.to_bool

    refute false.to_bool

    refute nil.to_bool
  end

  test 'invalid' do
    %w[t true yes false whatever].each do |string|
      assert_raise(ArgumentError, "#{string} did not raise") do
        string.to_bool
      end
    end

    assert_raise(NoMethodError) do
      Object.new.to_bool
    end
  end
end
