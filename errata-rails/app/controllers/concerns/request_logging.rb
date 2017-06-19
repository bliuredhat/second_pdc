module RequestLogging
  extend ActiveSupport::Concern

  included do
    prepend_around_filter do |controller, block|
      start_time = Time.now

      RequestLogging.log_request_begin(controller, start_time)

      begin
        block.call
      ensure
        RequestLogging.log_request_end(controller, start_time)
      end
    end
  end

  def self.log_request_begin(controller, start_time)
    REQUESTS_LOG.info 'Started %s at %s' % [
      request_brief(controller.request),
      start_time.to_default_s ]

    REQUESTS_LOG.info "Parameters: #{controller.params.inspect.truncate(250)}"
  end

  def self.log_request_end(controller, start_time)
    completed_time = Time.now
    request_time_sec = (completed_time - start_time)

    REQUESTS_LOG.info 'Completed %s at %s (time: %.2f, status: %s)' % [
      request_brief(controller.request),
      completed_time.to_default_s,
      request_time_sec,
      controller.response.status ]
  end

  def self.request_brief(request)
    remote = request.ip
    if (port = request.env['REMOTE_PORT'])
      remote += ":#{port}"
    end

    '%s "%s" for %s' % [
        request.request_method,
        request.filtered_path,
        remote]
  end
end
