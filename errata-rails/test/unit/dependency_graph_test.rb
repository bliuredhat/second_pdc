require 'test_helper'

class DependencyGraphTest < ActiveSupport::TestCase

  # It's convenient to use Async but it shouldn't matter much
  def scratch_advisory(name)
    RHBA.create(
      :reporter => qa_user,
      :product => Product.find_by_short_name('RHEL'),
      :release => async_release,
      :assigned_to => qa_user,
      :content => Content.new(:topic => name, :description => 'test', :solution => 'fix it')
    )
  end

  # TODO: how does this happen in reality??
  def make_child(parent, child)
    parent.blocking_errata << child
    child.dependent_errata << parent
  end

  test "basic stuff" do
    # Create some of advisories to play with
    assert @child = scratch_advisory('child')
    assert @parent1 = scratch_advisory('parent1')
    assert @parent2 = scratch_advisory('parent2')
    assert @grandparent = scratch_advisory('grandparent1')

    make_child(@parent1, @child)
    make_child(@parent2, @child)
    make_child(@grandparent, @parent1)

    assert_equal [@parent1, @grandparent, @parent2], DependencyGraph::Errata.new(@child).all_ancestors
    assert_equal [@parent1, @child], DependencyGraph::Errata.new(@grandparent).all_descendants

    assert_equal [@parent1, @grandparent, @parent2], @child.possibly_blocks
    assert_equal [@parent1, @child], @grandparent.possibly_blocked_by
    assert_equal [@child], @parent2.possibly_blocked_by
  end
end
