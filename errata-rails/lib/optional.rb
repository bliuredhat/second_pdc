module Optional
  # Call a given block, catching and logging any exception thrown.
  # Intended for executing tasks that should work, but if they do not,
  # sould not cause the more important containing task to fail.
  #
  # Syntactic sugar to avoid tons of begin..rescue statements
  def optionally(name = '', logger = Rails.logger)
    begin
      yield
    rescue Exception => e
      logger.error "Task #{name} failed: #{e.class} - #{e.to_s}\n#{e.backtrace.join("\n")}"
    end
  end
end
