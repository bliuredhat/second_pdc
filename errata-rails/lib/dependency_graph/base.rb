#
# Decided it was better to make a class for this rather than
# adding spaghetti methods to the Errata model.
#
# For fun, will try to write a general purpose class for
# dependencies. :)
#
module DependencyGraph
  class Base
    RECURSION_DEPTH_LIMIT = 5

    def children_method
      raise "Please define children_method in subclass"
    end

    def parents_method
      raise "Please define parents_method in subclass"
    end

    def get_parents(node)
      node.send(parents_method)
    end

    def get_children(node)
      node.send(children_method)
    end

    def initialize(start_node)
      @start_node = start_node
    end

    def each_ancestor(&block)
      tree_iterator(parents_method, @start_node, 1, &block)
    end

    def each_descendant(&block)
      tree_iterator(children_method, @start_node, 1, &block)
    end

    def all_descendants
      flatten_list(:each_descendant)
    end

    def all_ancestors
      flatten_list(:each_ancestor)
    end

    def has_ancestor?
      all_ancestors.any?
    end

    def has_descendant?
      all_descendants.any?
    end

    # There's probably a more elegant way to do this.
    # Going to just check if we hit the depth limit.
    def is_circular?
      max_level = 0
      each_ancestor   { |_, level| max_level = [max_level, level].max }
      each_descendant { |_, level| max_level = [max_level, level].max }
      max_level == RECURSION_DEPTH_LIMIT
    end

    private

    def tree_iterator(use_method, node, level, &block)
      node.send(use_method).each do |relative|
        if level < RECURSION_DEPTH_LIMIT
          yield relative, level
          tree_iterator(use_method, relative, level+1, &block)
        else
          # Use nil to indicate limit reached.
          # Might revisit this later..
          # Perhaps throw an exception?
          yield nil, level
        end
      end
    end

    def flatten_list(use_method)
      result = []
      self.send(use_method) do |relative, level|
        result << relative
      end
      result
    end

  end
end
