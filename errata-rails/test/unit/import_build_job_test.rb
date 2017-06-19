require 'test_helper'

class ImportBuildJobTest < ActiveSupport::TestCase
  setup do
    # This product listing cache is being mapped to an advisory
    @plc_with_advisory = ProductListingCache.find(1009215)

    # This product listing cache does not map to any advisory
    @plc_no_advisory = ProductListingCache.find(1009214)

    # We run all delayed jobs during this test, so clean them first to
    # ensure no unrelated code runs
    Delayed::Job.delete_all
  end

  test "should not enqueue if product listing is being mapped to an advisory" do
    assert_no_difference("Delayed::Job.count") do
      BrewJobs::ImportBuildJob.maybe_enqueue(@plc_with_advisory.product_version_id, @plc_with_advisory.brew_build.nvr)
    end
  end

  test "should not enqueue if product listing exists and is not empty" do
    assert_no_difference("Delayed::Job.count") do
      BrewJobs::ImportBuildJob.maybe_enqueue(@plc_no_advisory.product_version_id, @plc_no_advisory.brew_build.nvr)
    end
  end

  test "should enqueue if nvr not exist" do
    assert_difference("Delayed::Job.count", 1) do
      BrewJobs::ImportBuildJob.maybe_enqueue(@plc_with_advisory.product_version_id, "a-new-build-9999.el999")
    end
  end

  test "should enqueue if listing is not cached" do
    # Pretending we can't find the product listing cache
    ProductListingCache.expects(:find_by_product_version_id_and_brew_build_id).once.returns(nil)

    assert_difference("Delayed::Job.count", 1) do
      BrewJobs::ImportBuildJob.maybe_enqueue(@plc_with_advisory.product_version_id, @plc_with_advisory.brew_build.nvr)
    end
  end

  test "should enqueue if product listing cache is NOT being mapped to an advisory and is empty" do
    # Hack the cache to make it empties
    ProductListingCache.any_instance.expects(:cache).once.returns("--- {}\n\n")

    assert_difference("Delayed::Job.count", 1) do
      BrewJobs::ImportBuildJob.maybe_enqueue(@plc_no_advisory.product_version_id, @plc_no_advisory.brew_build.nvr)
    end
  end

  test "enqueue" do
    brew_build = @plc_no_advisory.brew_build
    product_version = @plc_no_advisory.product_version

    # Hack the cache to make it empties
    ProductListingCache.any_instance.expects(:cache).twice.returns("--- {}\n\n")

    assert_difference("Delayed::Job.count", 1) do
      BrewJobs::ImportBuildJob.maybe_enqueue(product_version.id, brew_build.nvr)
    end

    BrewBuild.expects(:make_from_rpc_without_mandatory_srpm).once.returns(brew_build)
    ProductVersion.expects(:find_by_id).once.returns(product_version)
    ProductListing.expects(:find_or_fetch).with(product_version, brew_build, {:use_cache => false})

    run_all_delayed_jobs
  end

  test "skip_find_or_fetch_when_the_initial_enqueue_condition_breaks" do
    brew_build = @plc_no_advisory.brew_build
    product_version = @plc_no_advisory.product_version

    # Firstly, a job is enqueued because the product listing cache has empty cache
    # and it is not mapping to any advisory
    ProductListingCache.any_instance.expects(:cache).once.returns("--- {}\n\n")

    assert_difference("Delayed::Job.count", 1) do
      BrewJobs::ImportBuildJob.maybe_enqueue(product_version.id, brew_build.nvr)
    end

    # Before the delayed job starts, another user maps the product listing cache to an advisory
    # using an API asynchronously
    ProductListingCache.any_instance.expects(:has_errata?).once.returns(true)

    BrewBuild.expects(:make_from_rpc_without_mandatory_srpm).once.returns(brew_build)
    ProductVersion.expects(:find_by_id).once.returns(product_version)
    # Since the condition has changed, we will skip the find_or_fetch
    ProductListing.expects(:find_or_fetch).never

    run_all_delayed_jobs
  end
end