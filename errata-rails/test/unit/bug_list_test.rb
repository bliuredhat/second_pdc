require 'test_helper'

class BugListTest < ActiveSupport::TestCase

  setup do
    @rhba = RHBA.new_files.first
  end

  test "buglist empty when bug not exist" do
    rhba_async = mock('RHBA')
    list = BugList.new('1 2', rhba_async)
    assert list.buglist.empty?, "Bug List should be empty!"
  end

  test "invalid when bugs in invalid state" do
    error_msg = "Bug list should not be valid, bugs in NEW state"
    errors = mock('errors')
    errors.expects(:full_messages).at_least_once.returns([error_msg])
    FiledBugSet.any_instance.stubs(:valid?).returns(false)
    FiledBugSet.any_instance.stubs(:errors).returns(errors)

    list = BugList.new('1 2', rhba_async)
    refute list.valid?, error_msg
  end

  test "correct mapping of bug ids" do
    list = BugList.new('1', RHBA.first)
    assert list.buglist.empty?

    expected_bugs = Bug.all.take(2).map(&:id)
    list = BugList.new(expected_bugs.join(' '), RHBA.first)
    assert_equal expected_bugs.join(','), list.bugids
  end

  def bug_list(advisory)
    BugList.new(advisory.bugs.map(&:id).join(','), advisory)
  end

  test "add bug" do
    list = bug_list(@rhba)
    assert list.valid?

    list.append(Bug.unfiled.with_states('MODIFIED').last.id)
    assert list.valid?
    assert_difference('@rhba.bugs.count') do
      list.save!
    end

    list.append(Bug.active.last.id)
    refute list.valid?

    bug = Bug.unfiled.with_states('MODIFIED').last
    BugList.any_instance.expects(:fetch_bugs_via_rpc).once.with(
      all_of(includes(6666666)))
    list.append(6666666)
  end

  test "add invalid bug" do
    advisory = Errata.new_files.where(:group_id => FastTrack.all).last
    assert_not_nil advisory, 'fixture problem: expected a NEW_FILES FastTrack advisory to exist'
    list = bug_list(advisory)

    list.append(Bug.unfiled.with_states('MODIFIED').last.id)
    refute list.valid?
  end

  test "remove bug" do
    list = bug_list(@rhba)
    list.remove(@rhba.bugs.last.id)
    assert list.buglist.empty?

    list = bug_list(@rhba)
    list.remove(12312321)
    assert list.valid?
    assert list.buglist.any?

    advisory = RHBA.find(10808)
    list = bug_list(advisory)
    assert_difference('advisory.bugs.count', -1) do
      list.remove(advisory.bugs.last.id)
      list.save!
    end
  end

  test 'empty ids gives empty list' do
    assert_equal [], BugList.new('', Errata.new_files.first).bugs
  end

  test 'can add using alias of single-alias bug' do
    errata = Errata.new_files.first
    bug    = Bug.find(1139115)

    # This bug has one alias
    assert_equal 'CVE-2014-3615', bug.alias

    # It should be possible to refer to it using the ID or alias
    assert_equal [bug], BugList.new('1139115', errata).bugs
    assert_equal [bug], BugList.new('CVE-2014-3615', errata).bugs
  end

  test 'can add using alias of multi-alias bug' do
    errata = Errata.new_files.first
    bug    = Bug.find(651183)

    # This bug has multiple aliases
    assert_equal(
      'CVE-2010-3879, CVE-2011-0541, CVE-2011-0542, CVE-2011-0543',
      bug.alias)

    # It should be possible to refer to it using the ID or any of the aliases
    assert_equal [bug], BugList.new('651183', errata).bugs
    assert_equal [bug], BugList.new('CVE-2010-3879', errata).bugs
    assert_equal [bug], BugList.new('CVE-2011-0541', errata).bugs
    assert_equal [bug], BugList.new('CVE-2011-0542', errata).bugs
    assert_equal [bug], BugList.new('CVE-2011-0543', errata).bugs
  end

  test 'can add very long aliases' do
    bug = Bug.find(651183)
    new_aliases = (1..200).collect{|i| "CVE-2016-%05d" % i}
    bug.update_attribute(:alias, new_aliases.join(', '))
    assert_equal new_aliases, bug.reload.aliases
  end
end
