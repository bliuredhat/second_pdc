module Delayed
  module MessageSending
    # Ensures that only one copy of a particular delayed method call
    # or job is put in the queue. Will need to port over and incorporate
    # into local lib when updating to latest delayed_job gem
    def enqueue_once(method_or_job, *args)
      payload, payload_args = case method_or_job
                              when String, Symbol
                                [Delayed::PerformableMethod.new(self, method_or_job.to_sym, args), []]
                              else
                                [method_or_job, args]
                              end

      # returns early so that INSERT..SELECT won't hold the lock
      return if Delayed::Job.where(:handler => payload.to_yaml).exists?

      priority = payload_args[0] || 0
      run_at = payload_args[1] || 5.minutes.from_now

      c = Delayed::Job.connection
      tbl = Delayed::Job.arel_table.name
      handler_sql = c.quote payload.to_yaml

      # achieves something like:
      #   INSERT INTO delayed_jobs VALUES(x, y, ...)
      #   WHERE handler <> 'handler_sql'
      sql = %{
        INSERT INTO #{tbl}(priority, handler, run_at, created_at, updated_at)
        SELECT #{c.quote priority}, #{handler_sql}, #{c.quote run_at}, NOW(), NOW()
        FROM (SELECT 1) AS `tmp`
        WHERE NOT EXISTS (
          SELECT 1 FROM #{tbl}
          WHERE handler = #{handler_sql}
        )
      }

      id = ActiveRecord::Base.transaction_with_retry { c.insert(sql) }
      Delayed::Job.find(id) if id != 0
    end

    def send_later(method, *args)
      Delayed::Job.enqueue Delayed::PerformableMethod.new(self, method.to_sym, args)
    end

    def send_at(time, method, *args)
      Delayed::Job.enqueue(Delayed::PerformableMethod.new(self, method.to_sym, args), 0, time)
    end

    def send_prioritized(priority, method, *args)
      Delayed::Job.enqueue(Delayed::PerformableMethod.new(self, method.to_sym, args), priority)
    end

    module ClassMethods
      def handle_asynchronously(method)
        aliased_method, punctuation = method.to_s.sub(/([?!=])$/, ''), $1
        with_method, without_method = "#{aliased_method}_with_send_later#{punctuation}", "#{aliased_method}_without_send_later#{punctuation}"
        define_method(with_method) do |*args|
          send_later(without_method, *args)
        end
        alias_method_chain method, :send_later
      end
    end
  end                               
end
