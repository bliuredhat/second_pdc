#
# A note on terminology (since I seem to get confused easily).
#
#   * We will say that an advisory "depends on" or
#     "is blocked by" its "child" advisories.
#
#   * Conversely we will say that an advisory "blocks" or
#     "is a dependency of" it's "parent" advisories.
#
# To help remember this, consider passengers on the titanic putting
# their children into a lifeboat before they themselves get in.
#
# Using this naming scheme, dependency graph arrows in Bugzilla point
# from child to parent.
#
# See:
#   lib/dependency_graph/base.rb
#   test/unit/dependency_graph_test.rb
#
module DependencyGraph
  class Errata < Base

    # This is used by methods in the base class
    def children_method
      :blocking_errata
    end

    # This is used by methods in the base class
    def parents_method
      :dependent_errata
    end

    #
    # Carefully define method names for readable code later
    # See commentary on terminology in lib/dependency_graph/base.rb.
    #
    # Notice I'm not defining 'blocking' or 'dependent' since that
    # terminology is already a bit confusing..!
    #
    alias_method :blocks,        :all_ancestors
    alias_method :blocked_by,    :all_descendants

    alias_method :dependency_of, :all_ancestors
    alias_method :depends_on,    :all_descendants

  end
end
