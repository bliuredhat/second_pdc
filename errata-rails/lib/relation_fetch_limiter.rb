# Provides support for limiting the number of items returned from a relation.
#
# This module is intended to be extended onto an ActiveRecord::Relation
# instance, as in the following example usage:
#
#   errata = Errata.active.extend(RelationFetchLimiter).fetch_limit(1000)
#   # will crash if there are >1000 items to load:
#   errata.each{|e| ... }
#
module RelationFetchLimiter
  attr_accessor :fetch_limit_value

  # Returns a copy of this relation with the fetch limit set to +value+, or
  # unlimited if nil.
  #
  # When calling any methods which would trigger the loading of records from the
  # database (such as to_a or each), if there are more than +value+ records to
  # be loaded, the relation will raise a FetchLimitExceededError.
  #
  # The primary use-case of this method is to impose a hard limit on the number
  # of records returned by legacy APIs lacking support for pagination.
  def fetch_limit(value)
    relation = clone
    relation.fetch_limit_value = value
    relation
  end

  private

  def self.extended(from)
    from.singleton_class.alias_method_chain :exec_queries, :limit
  end

  def exec_queries_with_limit
    RelationFetchLimiter.check_limit!(self, fetch_limit_value)
    exec_queries_without_limit
  end

  # Estimate of the number of elements this relation is expected to
  # load from the DB.
  def self.item_load_count(rel)
    if rel.respond_to?(:total_entries)
      # Relation is paginated.
      # per_page and total entries are upper bounds on the number of
      # elements we might return.
      [rel.total_entries, rel.per_page].min
    else
      # Relation is not paginated, it would load the full count of records.
      rel.count
    end
  end

  def self.check_limit!(rel, limit)
    return if rel.loaded?
    return unless limit

    would_load = self.item_load_count(rel)
    if would_load > limit
      fail FetchLimitExceededError,
        "#{rel.model_name} count #{would_load} exceeds internal limit of #{limit}"
    end
  end
end
