require 'test_helper'

class BugDependencyTest < ActiveSupport::TestCase
  test 'can store via blocks' do
    (bug1, bug2) = no_dependency_bugs.limit(2).to_a

    assert_equal [], bug1.blocks.to_a
    assert_equal [], bug1.depends_on.to_a
    assert_equal [], bug2.blocks.to_a
    assert_equal [], bug2.depends_on.to_a

    bug1.blocks << bug2
    bug2.reload

    assert_equal [bug2], bug1.blocks.to_a
    assert_equal [],     bug1.depends_on.to_a
    assert_equal [],     bug2.blocks.to_a
    assert_equal [bug1], bug2.depends_on.to_a
  end

  test 'can store via depends_on' do
    (bug1, bug2) = no_dependency_bugs.limit(2).to_a

    assert_equal [], bug1.blocks.to_a
    assert_equal [], bug1.depends_on.to_a
    assert_equal [], bug2.blocks.to_a
    assert_equal [], bug2.depends_on.to_a

    bug1.depends_on << bug2
    bug2.reload

    assert_equal [],     bug1.blocks.to_a
    assert_equal [bug2], bug1.depends_on.to_a
    assert_equal [bug1], bug2.blocks.to_a
    assert_equal [],     bug2.depends_on.to_a
  end

  test 'cannot duplicate' do
    (bug1, bug2) = no_dependency_bugs.limit(2).to_a

    bug1.depends_on << bug2
    assert_raises(ActiveRecord::RecordNotUnique) do
      bug1.depends_on << bug2
    end
  end

  test 'update_from_rpc updates records appropriately' do
    bug = no_dependency_bugs.limit(8).to_a

    BugDependency.delete_all

    bug[0].blocks << bug[1]
    bug[0].blocks << bug[2]
    bug[0].depends_on << bug[4]
    bug[0].depends_on << bug[5]

    deps = BugDependency.all.to_a

    # Should have 4 dependency records...
    assert_equal 4, deps.length

    # Now the bug changes in bugzilla, it gains and loses some depends_on and
    # blocks.
    rpc_bug = mock().tap do |m|
      m.stubs(
        :bug_id     => bug[0].id,
        # Remove 1 and add 1 blocks
        :blocks     => bug[2..3].map(&:id),
        # Remove 1 and add 2 depends_on
        :depends_on => bug[5..7].map(&:id))
    end

    BugDependency.update_from_rpc(rpc_bug)

    later_deps = BugDependency.all.to_a

    deleted_deps = deps - later_deps
    added_deps   = later_deps - deps
    kept_deps    = later_deps & deps

    # These are the expected counts of each type of change.  This is testing
    # that dependency objects aren't unnecessarily deleted and recreated.
    assert_equal 2, deleted_deps.length
    assert_equal 3, added_deps.length
    assert_equal 2, kept_deps.length

    # The dependency information should match up with the last RPC info...
    bug.each(&:reload)

    assert_equal bug[2..3], bug[0].blocks.order('id asc')
    assert_equal bug[5..7], bug[0].depends_on.order('id asc')

    assert_equal [],        bug[1].blocks
    assert_equal [],        bug[1].depends_on

    assert_equal [],        bug[2].blocks
    assert_equal [bug[0]],  bug[2].depends_on

    assert_equal [],        bug[3].blocks
    assert_equal [bug[0]],  bug[3].depends_on

    assert_equal [],        bug[4].blocks
    assert_equal [],        bug[4].depends_on

    assert_equal [bug[0]],  bug[5].blocks
    assert_equal [],        bug[5].depends_on

    assert_equal [bug[0]],  bug[6].blocks
    assert_equal [],        bug[6].depends_on

    assert_equal [bug[0]],  bug[7].blocks
    assert_equal [],        bug[7].depends_on
  end

  test 'update_from_rpc handles missing bugs OK' do
    bug = no_dependency_bugs.limit(8).to_a

    ID1 = 77788888
    ID2 = 88899999

    DirtyBug.delete_all
    BugDependency.delete_all

    rpc_bug = mock().tap do |m|
      m.stubs(
        :bug_id     => bug[0].id,
        # For blocks and depends, simulate one known bug and one unknown bug in
        # the list
        :blocks     => [bug[1].id, ID1],
        :depends_on => [bug[2].id, ID2])
    end

    # It should mark those two unknown bugs as dirty and ignore others
    assert_difference('DirtyBug.count', 2) do
      BugDependency.update_from_rpc(rpc_bug)
    end

    bug[0].reload

    assert_equal [ID1, ID2], DirtyBug.order('record_id asc').pluck('record_id')

    # Initially, the nonexistent bugs won't be returned by blocks/depends
    assert_equal [bug[1]],         bug[0].blocks
    assert_equal [bug[2]],         bug[0].depends_on

    # However, as soon as the records are synced, they'll be accessible,
    # since the dependency data already exists
    mkbug = lambda do |id|
      Bug.new(:package => Package.first,
              :bug_status => 'CLOSED',
              :short_desc => 'test bug').tap do |b|
        b.id = id
        b.save!
      end
    end
    newbug1 = mkbug[ID1]
    newbug2 = mkbug[ID2]

    bug[0].reload

    assert_equal [bug[1], newbug1], bug[0].blocks.order('id asc')
    assert_equal [bug[2], newbug2], bug[0].depends_on.order('id asc')
  end

  test 'update_from_rpc handles removed dependencies' do
    bug = no_dependency_bugs.limit(7).to_a

    BugDependency.delete_all

    bug[0].blocks << bug[1]
    bug[0].blocks << bug[2]
    bug[0].depends_on << bug[4]
    bug[0].depends_on << bug[5]
    bug[0].depends_on << bug[6]

    deps = BugDependency.all.to_a

    # Should have 5 dependency records...
    assert_equal 5, deps.length

    # Now the bug changes in bugzilla, it only loses all blocks.
    rpc_bug = mock().tap do |m|
      m.stubs(
        :bug_id     => bug[0].id,
        # Remove 2 blocks
        :blocks     => '',
        # Keep 3 depends_on
        :depends_on => bug[4..6].map(&:id))
    end

    BugDependency.update_from_rpc(rpc_bug)

    _2nd_deps = BugDependency.all.to_a

    # These are the expected counts of each type of change.  This is testing
    # that dependency objects aren't unnecessarily deleted and recreated.
    assert_equal 2, (deps - _2nd_deps).length # deleted
    assert_equal 0, (_2nd_deps - deps).length # added
    assert_equal 3, (_2nd_deps & deps).length # kept

    # Now the bug changes in bugzilla, it gains blocks and loses depends_on.
    rpc_bug = mock().tap do |m|
      m.stubs(
        :bug_id     => bug[0].id,
        # Add 2 blocks
        :blocks     => bug[3..4].map(&:id),
        # Remove 3 depends_on
        :depends_on => '')
    end

    BugDependency.update_from_rpc(rpc_bug)

    _3rd_deps = BugDependency.all.to_a

    # These are the expected counts of each type of change.  This is testing
    # that dependency objects aren't unnecessarily deleted and recreated.
    assert_equal 3, (_2nd_deps - _3rd_deps).length #deleted
    assert_equal 2, (_3rd_deps - _2nd_deps).length # added
    assert_equal 0, (_3rd_deps & _2nd_deps).length # kept

  end

  def no_dependency_bugs
    Bug.
      where('id not in (?)', BugDependency.pluck('distinct bug_id')).
      where('id not in (?)', BugDependency.pluck('distinct blocks_bug_id')).
      order('id asc')
  end
end
