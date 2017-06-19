module Push
  class PubWatcher
    def perform
      PubWatcher.perform
    end

    def rerun?
      true
    end

    def self.enqueue
      Delayed::Job.enqueue self.new, 10, 5.minutes.from_now
    end

    # Do a single iteration of the poll for completed push jobs.
    #
    # This will do:
    # - find any push jobs waiting for pub to complete
    # - query pub for the task status
    # - mark jobs as completed or failed appropriately
    #
    # This method can be called both from the associated delayed job and from
    # user requests.
    def self.perform
      ids = PushJob.connection.select_values("select distinct pub_task_id from push_jobs where status = 'WAITING_ON_PUB'").collect { |i| i.to_i }
      return if ids.empty?
      client = PubClient.get_connection
      pub_tasks = client.get_tasks(ids)
      complete = pub_tasks.select { |task| task['is_finished'] }
      complete.each do |t|
        PushJob.for_pub_task(t['id']).each do |job|
          # PubWatcher may be executed from both delayed jobs and any number of
          # rails server threads, at the same time.
          # Grab a lock on the job to ensure it's not concurrently modified.
          #
          # Note that with_lock implicitly reloads, so this will have the latest
          # job status.
          job.with_lock do

            # Do nothing if already processed by another thread since we started.
            next unless job.status == 'WAITING_ON_PUB'

            if t['is_failed']
              job.mark_as_failed!("Pub task failed")
            else
              job.pub_success!(:process_later => true)
            end
          end
        end
      end
    end

  end
end
