class TransactionRetry
  MAX_ATTEMPTS = 5

  # Returns true only if, according to the given +error+ from a transaction (which has already
  # been tried +attempt+ times), the transaction should be retried.
  #
  # May also log a warning.
  def self.should_retry?(attempt, error)
    # NOTE: specific to MySQL
    return false unless error.is_a?(ActiveRecord::StatementInvalid)

    message = error.message
    return false unless message =~ /try restarting transaction: /

    prefix = "[#{attempt}/#{MAX_ATTEMPTS}]"

    if attempt < MAX_ATTEMPTS
      Rails.logger.warn "#{prefix} retrying transaction: #{message}"
      true
    else
      Rails.logger.warn "#{prefix} abandoning transaction: #{message}"
      false
    end
  end

  # Perform a transaction, as ActiveRecord::Base.transaction.
  #
  # Retry it, up to some implementation-defined number of times, if the
  # transaction fails due to a deadlock.
  def self.transaction_with_retry(*args, &block)
    attempt = 1
    delays = []
    begin
      ActiveRecord::Base.transaction(*args, &block)
    rescue => e
      if should_retry?(attempt, e)
        attempt += 1

        # Mitigate thundering herds problem.
        #
        # If we have N threads around the same time hitting an area of the code
        # where it's common for 1 thread to succeed and (N-1) threads to be
        # rolled back due to deadlock, we'd prefer them not to all retry the
        # transaction at the same time since there's a high chance of triggering
        # the problem again for the remaining threads.  A quick sleep with a
        # different value per thread will improve overall throughput in this
        # scenario.

        delay = rand + 0.04 * 2**attempt # exponential wait
        delays << delay
        sleep delay
        retry
      end
      Rails.logger.warn "TransactionRetry raised after [#{delays.join(', ')}]" if delays.any?
      raise e
    end
  end
end
