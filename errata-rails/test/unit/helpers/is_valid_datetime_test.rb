require 'test_helper'

class IsValidDatetimeTest < ActiveSupport::TestCase
  include IsValidDatetime

  test "date string validation" do
    [
      Date.current.to_s,
      '2013-AUG-10',
      '2013-Aug-20',
      '2013-08-01',
      '2013-08-1',
      '2013-DEC-1',
      '2013-aUg-30',
      '  2013-Aug-30  ',
    ].each do |datestring|
      assert is_valid_datetime(datestring), "#{datestring} should be valid"
    end

    [
      nil,
      '',
      '    ',
      'asdf',
      '2013-33-02',
      '2013-Aug-32',
      '2013-Feb-29',
      '2013-Fab-14',
      '2013-33-20',
      '2013.33-03',
      '2013,33,33',
      '13/01/01',
      '2013/01/01',
      '2013',
      '2013-1-1',
    ].each do |datestring|
      refute is_valid_datetime(datestring), "#{datestring} should be invalid"
    end
  end

end
