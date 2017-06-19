module MessageBus::QpidHandler::Ccat
  MESSAGE_TYPES = [:fail, :pass, :running]
  RESULT_TYPES = %w(pass fail)

  class CcatMessage
    attr_accessor :errata, :message_type, :external_test_type,
                  :external_test_run, :external_id, :result, :error_cause, :issue_key,
                  :pub_target

    # Assembles and returns the message to be stored/displayed in ET, which may
    # be calculated based on several fields of this CCAT message.
    def message_for_display
      issue_url = nil
      if issue_key
        issue_url = Settings.rcm_jira_issue_url % issue_key
      end

      [error_cause, issue_url].reject(&:blank?).join("\n")
    end
  end

  extend ActiveSupport::Concern

  included do
    add_subscriptions(:ccat_subscriptions)
  end

  def ccat_subscriptions
    exchange = Settings.qpid_ccat_exchange
    topic = Settings.qpid_ccat_topic

    topic_subscribe(exchange, topic) do |content, raw_msg|
      begin
        ActiveRecord::Base.transaction do
          ccat_handle_message(content, raw_msg)
        end
      rescue => e
        MBUSLOG.error "Error processing CCAT message #{content.inspect.truncate(120)} #{raw_msg.getProperties.inspect.truncate(120)}"
        MBUSLOG.error e
      end
    end
  end

  def ccat_handle_message(content, raw_msg)
    msg = ccat_parse_message(content, raw_msg)
    method = "ccat_handle_#{msg.message_type}"
    send(method, msg)
  end

  def ccat_handle_testing_started(msg)
    if msg.external_test_run
      raise "Got a 'test started' message for a run #{msg.external_test_run.id} already existing"
    end

    run = ccat_create_run(msg)

    MBUSLOG.info "Testing started: #{run.name} #{run.external_id}"
  end
  alias_method :ccat_handle_running, :ccat_handle_testing_started

  def ccat_handle_testing_completed(msg)
    run = msg.external_test_run
    unless run
      # We'll accept 'test completed' messages for runs we haven't seen, but
      # it's unusual
      run = ccat_create_run(msg)
      MBUSLOG.warn 'Testing completed for previously unseen test run'
    end

    run.external_status = msg.result
    run.external_message = msg.message_for_display
    run.status = (msg.result == 'pass' ? 'PASSED' : 'FAILED')
    run.save!

    MBUSLOG.info "Testing completed: #{run.name} #{run.external_id} #{run.external_status}"
  end
  alias_method :ccat_handle_pass, :ccat_handle_testing_completed
  alias_method :ccat_handle_fail, :ccat_handle_testing_completed

  def ccat_create_run(msg)
    # Any earlier active runs of a compatible type are superseded by this one
    superseded = msg.errata.external_test_runs_for(msg.external_test_type.with_related_types).active.to_a

    created = ExternalTestRun.create!(
      :external_test_type => msg.external_test_type,
      :external_message => msg.message_for_display,
      :pub_target => msg.pub_target,
      :external_status => 'PENDING',
      :external_id => msg.external_id,
      :status => 'PENDING',
      :errata => msg.errata)

    superseded.each do |run|
      run.active = 0
      run.superseded_by = created
      run.save!
    end

    created
  end

  # Determines context from the message, or bails out if certain mandatory
  # properties are missing
  def ccat_parse_message(content, raw_msg)
    props = raw_msg.getProperties()

    out = CcatMessage.new

    out.errata = Errata.find(props['ERRATA_ID'])

    test_type_name = case props['JOB_NAME']
                     when 'cdn_content_validation_manual'
                       'ccat/manual'
                     else
                       'ccat'
                     end

    out.external_test_type = ExternalTestType.find_by_name!(test_type_name)

    out.error_cause = ccat_parse_error_cause(props['ERROR_CAUSE'])
    out.issue_key = props['JIRA_ISSUE_ID']

    out.pub_target = props['TARGET']

    # FIXME? The build number is not directly available in the message anywhere,
    # so we extract it from the URL.  It seems odd. Maybe we should request
    # adding the build number in the message.
    url = content['BUILD_URL']
    build_number = url.split(/[^0-9]+/).last.to_i

    raise "Could not calculate build number from #{url}" if build_number == 0

    out.external_id = build_number

    # We may or may not have the run object at this point
    out.external_test_run = ExternalTestRun.
                            where(:external_id => build_number,
                                  :external_test_type_id => out.external_test_type).
                            first

    # If we do have the run already, verify that it matches the errata
    if out.external_test_run
      if out.external_test_run.errata != out.errata
        raise "Test previously referred to #{out.external_test_run.errata.fulladvisory} and now refers to #{out.errata.fulladvisory}"
      end
    end

    out.result = props['MESSAGE_TYPE'] if RESULT_TYPES.include? props['MESSAGE_TYPE']

    out.message_type = props['MESSAGE_TYPE'].to_sym
    unless MESSAGE_TYPES.include?(out.message_type)
      raise "Unknown message type #{props['MESSAGE_TYPE']}"
    end

    out
  end

  def ccat_parse_error_cause(str)
    return nil if str.blank?

    # The error cause may look like this:
    #
    #   '["Metadata Error", "Content not available"]'
    #
    # It's expected to be a JSON-formatted array.  Note however that earlier
    # versions of CCAT used a different format, and in any case we don't want to
    # fail processing messages if this property is corrupt.  So we'll tolerate
    # (with complaint) unparsable values.
    begin
      JSON.parse(str).join("\n")
    rescue => e
      MBUSLOG.warn "Ignored CCAT ERROR_CAUSE = #{str.inspect}: #{e}"
      nil
    end
  end
end
