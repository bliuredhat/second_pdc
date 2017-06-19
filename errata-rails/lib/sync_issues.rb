module SyncIssues
  def with_checkpoints(sync_type, start_from, now, log, &block)
    from_date = start_from.localtime
    checkpoint = Settings.send("#{sync_type}_checkpoint") || 6.hours

    while (true)
      # Make a 1 week checkpoint by default, so that it can resume the update
      # if it can't finish within the limited time.
      to_date = from_date + checkpoint

      to_minutes_diff = ((now - to_date) / 60).to_i
      to_date = (to_minutes_diff > 0) ? to_date : now

      yield(from_date, to_date)

      # set checkpoint
      Settings.send("#{sync_type}_timestamp=", to_date)

      log.info "Current Checkpoint: #{to_date}"

      break if to_minutes_diff <= 0
      from_date = to_date
    end
  end
end