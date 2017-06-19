require 'test_helper'

class DirtyRecordObserverTest < ActiveSupport::TestCase
  test "enqueue job with invalid record type" do
    bug = Bug.first
    error = assert_raises(ArgumentError) do
      InvalidDirtyRecord.create(:record_id => bug.id, :last_updated => Time.now)
    end

    assert_equal "Invalid dirty record type 'InvalidDirtyRecord'.", error.message
  end

  test "enqueue a job" do
    bugs = Bug.limit(3)
    jobs = get_job

    # shouldn't have any job in the beginning
    assert_equal 0, jobs.length

    DirtyBug.create(:record_id => bugs[0].id, :last_updated => Time.now)

    assert_equal 1, jobs.reload.length

    DirtyBug.create(:record_id => bugs[1].id, :last_updated => Time.now)

    # should only enqueue once
    assert_equal 1, jobs.reload.length

    # still 1 job is enqueued, even the job handler object doesn't have
    # the same content.
    make_mutant_job(jobs.first)
    DirtyBug.create(:record_id => bugs[2].id, :last_updated => Time.now)

    assert_equal 1, jobs.reload.length
  end

  def make_mutant_job(job)
    job_handler = Bugzilla::UpdateDirtyBugsJob.new
    job_handler.instance_variable_set("@message", "This is a test.")

    job.payload_object = job_handler
    job.save!
  end

  def get_job
    Delayed::Job.where("handler like ?", "%Bugzilla::UpdateDirtyBugsJob%")
  end
end

class InvalidDirtyRecord < DirtyRecord
end