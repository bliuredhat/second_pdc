module MessageBus
  # Denotes a +block+ as a periodic reconciliation process, invoked depending
  # on message bus activity.
  #
  # +settingkey+ is the basename of two settings keys.
  # +mbus_#{settingkey}_enabled+ is read to determine whether the message bus handler
  # for this process is enabled.
  # +#{settingkey}_timestamp+ is read and written to determine when the process has
  # last run.
  #
  # The block will be invoked if and only if one of the following is true:
  #
  #  - the relevant message bus handler is disabled
  #  - the message bus service has not run recently (~15 minutes)
  #  - the reconcile block has not run in the last ~12 hours
  #
  # If invoked, the block receives a single argument: the value of the +#{settingkey}_timestamp+
  # timestamp (i.e. the last time the reconciliation was performed).
  #
  def reconcile(settingkey, &block)
    last_sync = Settings.send("#{settingkey}_timestamp")
    mbus_enabled = Settings.send("mbus_#{settingkey}_enabled")
    last_mbus = Settings.mbus_last_receive
    now = Time.now

    do_poll = if last_mbus.nil?
      MBUSLOG.debug "Message bus never used - polling is always activated for #{settingkey}"
      true
    elsif !mbus_enabled
      MBUSLOG.debug "Message bus used, but handler is disabled - polling activated for #{settingkey}"
      true
    elsif now - last_mbus > 15.minutes
      MBUSLOG.warn "Message bus is not receiving! Falling back to poll for #{settingkey}"
      true
    elsif now - last_sync > 12.hours
      MBUSLOG.debug "Polling to reconcile with message bus for #{settingkey}"
      true
    else
      MBUSLOG.debug "No need to poll for #{settingkey}"
      false
    end

    if do_poll
      block.call(last_sync, now)
      Settings.send("#{settingkey}_timestamp=", now)
    end
  end
  module_function(:reconcile)
end
