module MessageBus::QpidHandler::Covscan
  extend ActiveSupport::Concern

  included do
    add_subscriptions(:covscan_subscriptions)
  end

  def covscan_subscriptions
    exchange = Qpid::COVSCAN_EXCHANGE
    topic_prefix = Qpid::COVSCAN_TOPIC_PREFIX

    #
    # When a covscan scan is finished (or unfinished) a message is
    # placed on the bus like this:
    # {"scan_state"=>"QUEUED", "scan_id"=>9842}
    #
    topic_subscribe(exchange, "#{topic_prefix}.finished") do |content, msg|
      covscan_handle_message(content, msg)
    end

    topic_subscribe(exchange, "#{topic_prefix}.unfinished") do |content, msg|
      covscan_handle_message(content, msg)
    end
  end

  #
  # Currently doing the same thing with finished and unfinished messages.
  #
  def covscan_handle_message(content, msg)
    output(content, msg)

    scan_id = content['scan_id']
    scan_state = content['scan_state']

    test_run = ExternalTestRun.find_run(:covscan, scan_id)
    if test_run
      # Update the run's status
      say "Updating scan status for #{test_run.id}"
      test_run.covscan_status_update(scan_state)
    else
      # We know nothing about this scan so let's ignore it
      say "Can't find test run record, ignoring"
    end
  end

end
