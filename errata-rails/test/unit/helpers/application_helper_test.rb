require 'test_helper'
require 'ostruct'
require 'stringio'


class ApplicationHelperTest < ActiveSupport::TestCase
  include ApplicationHelper

  setup do
    @old_stderr = $stderr
  end

  teardown do
    $stderr = @old_stderr
  end

  test "object row id" do
    $stderr = StringIO.new

    record = OpenStruct.new :name => 'frob'
    assert_nil object_row_id(record)
    assert $stderr.string.empty?

    assert_equal "rhba_#{RHBA.qe.first.id}", object_row_id(RHBA.qe.first)
    assert $stderr.string.empty?
  end

end
