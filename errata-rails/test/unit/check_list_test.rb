#
# (Note: The only Rails dependency in lib/check_list is
# ActiveSupport::CoreExt::String::Inflections. It would be nice
# to make this test run without the Rails environment loaded, but
# I'm not going to worry about that for now.)
#
require 'test_helper'

class CheckListTest < ActiveSupport::TestCase

  class Person < Struct.new(:name, :age, :height)
    def to_s
      name
    end
  end

  def setup
    @person = Person.new("Bob", 29, 180)
  end

  class CanRideRollerCoaster < CheckList::List
    class OldEnough < CheckList::Check
      pass { @person.age > 9 }
      pass_message { "#{@person.name}, you are old enough to ride." }
      fail_message { "Sorry #{@person.name}, #{@person.age} is too young." }
      order 1
    end

    class TallEnough < CheckList::Check
      pass { @person.height > 145 }
      pass_message { "#{@person.name}, you are tall enough to ride." }
      fail_message { "Sorry #{@person.name}, #{@person.height} is too short." }
      order 2
    end

    class NoZNames < CheckList::Check
      title "Zed ban!"
      ivar_name :p
      setup { @name = @p.name }
      pass { @name !~ /^Z/ }
      order 3
    end
  end

  test "check lists" do
    c = CanRideRollerCoaster.new(@person)
    assert_equal 3, c.checks.length
    assert c.pass_all?
    assert_equal 3, c.pass_count
    assert_equal 0, c.fail_count

    # Test messages and result list
    pass_list, message_list, title_list = c.unzipped_result_list
    assert_equal [true, true, true], pass_list
    assert_equal ["Bob, you are old enough to ride.",
                  "Bob, you are tall enough to ride.",
                  "'Zed ban!' check passed for Bob"],  message_list
    assert_equal ['Old Enough', 'Tall Enough', 'Zed ban!'], title_list

    @person.age = 9
    c.check(@person)
    assert !c.pass_all?
    assert_equal 2, c.pass_count
    assert_equal 1, c.fail_count
    assert_equal "Sorry Bob, 9 is too young.", c.checks.first.message

    # Test the result_list with specified 'picks'
    assert_equal [[false], [true], [true]], c.result_list(:pass?)
    assert_equal [[false, true, true]], c.unzipped_result_list(:pass?)
    assert_equal [[false, 'Old Enough'], [true, 'Tall Enough'], [true, 'Zed ban!']], c.result_list(:pass?, :title)
    assert_equal [[false, true, true], ['Old Enough', 'Tall Enough', 'Zed ban!']], c.unzipped_result_list(:pass?, :title)

    @person.age = 9
    @person.height = 120
    c.check(@person)
    assert_equal ["Sorry Bob, 9 is too young.", "Sorry Bob, 120 is too short."], c.fail_messages
    assert_equal "Sorry Bob, 9 is too young. Sorry Bob, 120 is too short.", c.fail_text
  end

  class NoJNames < CheckList::Check
    pass { @person.name !~ /^J/ }
  end

  # Can also manually define the check_classes like this
  class SpecifiedClassesCheck < CheckList::List
    check_classes CanRideRollerCoaster::NoZNames, NoJNames
  end

  test "check lists with manually specified checks" do
    c = SpecifiedClassesCheck.new(@person)
    assert_equal 2, c.checks.length
    assert c.pass_all?

    @person.name = 'Janey'
    c.check(@person)
    refute c.pass_all?
    assert_equal 1, c.pass_count
    assert_equal 1, c.fail_count

    assert_equal "'Zed ban!' check passed for Janey", c.checks.first.message
    assert_equal "'No J Names' check failed for Janey", c.checks.last.message

    assert_equal "Zed ban!", c.checks.first.title
    assert_equal "No J Names", c.checks.last.title
  end

  class ArgsTest < CheckList::List
    class WithinRange < CheckList::Check
      ivar_name :num

      setup do
        @min ||= 5
        @max ||= 9
      end

      pass do
        @num >= @min && @num <= @max
      end

      note "Super important"
    end
  end

  test "check with args" do
    c = ArgsTest.new
    assert c.check(5).pass_all?
    refute c.check(10).pass_all?
    assert c.check(4, :min=>4).pass_all?
    refute c.check(4, :min=>1, :max=>3).pass_all?
    assert c.check(2, :min=>1, :max=>3).pass_all?
    assert_equal "'Within Range' check passed for 2", c.checks.first.message
    assert_equal "'Within Range' check failed for 11", c.check(11).checks.first.message
    assert_equal "Super important", c.checks.first.note
  end

end
