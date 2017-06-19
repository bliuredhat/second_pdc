require 'test_helper'

class BatchTest < ActiveSupport::TestCase

  test "batch must have a release" do
    b = Batch.new(:name => 'test_batch')
    refute b.valid?
    assert_errors_include(b, "Release can't be blank")
  end

  test "batching must be enabled for release" do
    release = Release.first
    release.enable_batching = false
    b = Batch.new(:name => 'test_batch', :release => release)
    refute b.valid?
    assert_errors_include(b, "Release '#{release.name}' does not have enable_batching set")
    release.enable_batching = true
    assert b.valid?
  end

  test "cannot alter release if batch has errata" do
    release = Release.first
    release.enable_batching = true
    erratum = Errata.where("group_id != #{release.id}").last
    erratum.release.enable_batching = true
    b = Batch.new(:name => 'test_batch', :release => erratum.release)
    erratum.batch = b
    erratum.save!
    b.release = release
    refute b.valid?
    assert_errors_include(b, "Release cannot be changed if batch has errata")
  end

  test "next batch ignores locked batches" do
    release = Release.find(452)

    # This batch has earlier release date but is locked
    batch = Batch.find(7)
    assert_not_equal batch, release.next_batch

    # Unlock batch, making it available as next_batch
    batch.unlock
    batch.save!
    assert_equal batch, release.next_batch

    # Lock batch, it is no longer available as next_batch
    batch.lock
    batch.save!
    assert_not_equal batch, release.next_batch
  end
end
