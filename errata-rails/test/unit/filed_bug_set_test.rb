require 'test_helper'

class FiledBugSetTest < ActiveSupport::TestCase

  test "bug rules validate set" do
    fbs = FiledBugSet.new(:bugs => [], :errata => rhba_async)
    assert fbs.valid?

    FiledBug.any_instance.stubs(:advisory_state_ok).returns(true)
    fbs = FiledBugSet.new(:bugs => [Bug.first, Bug.last], :errata => rhba_async)
    refute fbs.valid?
    assert fbs.errors.any?
  end

end
