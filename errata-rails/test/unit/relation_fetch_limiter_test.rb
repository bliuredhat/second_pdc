require 'test_helper'

class RelationFetchLimiterTest < ActiveSupport::TestCase
  setup do
    @errata_count = Errata.count
  end

  test "cannot fetch more than the limit" do
    error = assert_raises(FetchLimitExceededError) do
      extended_errata.fetch_limit(3).length
    end
    assert_equal(
      "Errata count #{@errata_count} exceeds internal limit of 3",
      error.message)
  end

  test "can fetch if paginating within the limit" do
    rel = extended_errata.fetch_limit(3)
    assert_equal 3, rel.paginate(:per_page => 3, :page => 1).length
    assert_equal 3, rel.paginate(:per_page => 3, :page => 2).length

    # Note that 'count' still reflects pre-paginate count, and can be queried
    # without error
    assert_equal @errata_count, rel.paginate(:per_page => 3, :page => 3).count
  end

  test "cannot fetch if paginating beyond the limit" do
    rel = extended_errata.fetch_limit(3)
    error = assert_raises(FetchLimitExceededError) do
      rel.paginate(:per_page => 4, :page => 1).length
    end
    assert_equal(
      "Errata count 4 exceeds internal limit of 3",
      error.message)
  end

  test "can fetch if limit unset" do
    assert_equal @errata_count, extended_errata.length
  end

  test "can fetch if limit greater/equal to count" do
    assert_equal @errata_count, extended_errata.fetch_limit(@errata_count).length
  end

  test "can fetch if limit set then raised" do
    assert_equal(
      @errata_count,
      extended_errata.fetch_limit(1).fetch_limit(@errata_count).length)
  end

  test "fetch_limit does not modify relation" do
    orig = extended_errata
    limit1 = orig.fetch_limit(2)
    limit2 = limit1.fetch_limit(4)
    unlimit = limit2.fetch_limit(nil)

    # each of the objects should have the configured behavior,
    # not affected by subsequent calls
    assert_equal @errata_count, orig.length

    error = assert_raises(FetchLimitExceededError) do
      limit1.length
    end
    assert_equal(
      "Errata count #{@errata_count} exceeds internal limit of 2",
      error.message)

    error = assert_raises(FetchLimitExceededError) do
      limit2.length
    end
    assert_equal(
      "Errata count #{@errata_count} exceeds internal limit of 4",
      error.message)

    assert_equal @errata_count, unlimit.length
  end

  def extended_errata
    Errata.scoped.extend(RelationFetchLimiter)
  end
end
