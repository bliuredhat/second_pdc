require 'test_helper'

class FormObjectTest < ActiveSupport::TestCase
  test 'save! raises if errors are set during validation' do
    form = DummyForm.new
    form.validate_errors[:foo] = 'some error'
    assert_raises(ActiveRecord::RecordInvalid) do
      form.save!
    end

    # can get the errors, and valid? does not wipe them out
    assert_equal ['some error'], form.errors[:foo]
    refute form.valid?
    assert_equal ['some error'], form.errors[:foo]
  end

  test 'save! raises if errors are set during persist!' do
    form = DummyForm.new
    form.persist_errors[:foo] = 'some error'
    assert_raises(ActiveRecord::RecordInvalid) do
      form.save!
    end

    # Can get the errors, but...
    # valid? returns true and wipes out the errors!
    # Could be considered correct, since valid? is supposed to be
    # about running validations, but it was confusing for me at
    # least.  Callers should be aware of it.
    assert_equal ['some error'], form.errors[:foo]
    assert form.valid?
    assert_equal [], form.errors[:foo]
  end

  test 'save returns false if errors are set during validation' do
    form = DummyForm.new
    form.validate_errors[:foo] = 'some error'
    assert_equal false, form.save

    # can get the errors, and valid? does not wipe them out
    assert_equal ['some error'], form.errors[:foo]
    refute form.valid?
    assert_equal ['some error'], form.errors[:foo]
  end

  test 'save returns false errors are set during persist!' do
    form = DummyForm.new
    form.persist_errors[:foo] = 'some error'
    assert_equal false, form.save

    assert_equal ['some error'], form.errors[:foo]
    # see same notes above re: valid? wiping out persist errors
    assert form.valid?
    assert_equal [], form.errors[:foo]
  end

  test 'save returns true if persist succeeds' do
    form = DummyForm.new
    assert form.save
  end

  test 'save! returns nil and does not raise if persist succeeds' do
    form = DummyForm.new
    assert_equal nil, form.save!
  end

  test 'errors raised by persist! propagate through save' do
    # This test is more about detecting changes in the current behavior
    # than asserting the correctness of that behavior.
    #
    # It doesn't seem right that the non-throwing "save" calls
    # "persist!"  which, by its name, is obviously intended to throw.
    # Nevertheless it would be dangerous to change it now, since this
    # propagation might be the only way that certain errors are
    # detected at the moment...
    form = DummyForm.new
    form.persist_raise = 'BOING'
    assert_raises(RuntimeError) do
      form.save
    end
  end

  class DummyForm
    include FormObject

    attr_accessor :persist_errors, :persist_raise, :validate_errors

    def initialize
      @persist_errors = ActiveSupport::OrderedHash.new
      @validate_errors = ActiveSupport::OrderedHash.new
    end

    def persist!
      @persist_errors.each do |key,val|
        errors.add(key,val)
      end
      if @persist_raise
        raise @persist_raise
      end
      'some value'
    end

    validate do
      @validate_errors.each do |key,val|
        errors.add(key,val)
      end
    end
  end
end
