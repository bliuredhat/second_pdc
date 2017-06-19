module ErrorHandling
  extend ActiveSupport::Concern
  include CurrentUser, CleanBacktrace

  included do
    #
    # Catch exceptions in non-dev environments so we can display a more user friendly
    # error message instead of a stack trace and session dump etc.
    #
    unless Rails.env.development?
      # This doesn't work any more. :( There is a workaround here:
      # http://techoctave.com/c7/posts/36-rails-3-0-rescue-from-routing-error-solution
      # (Maybe use this workaround when we update config/routes.rb)
      rescue_from ActionController::RoutingError, :with => :route_not_found

      # The server_error method will send an ExceptionNotifier email and display
      # an "error has occurred" page.
      rescue_from Exception, :with => :server_error
    end
    rescue_from PDC::TokenFetchFailed, :with => :fetch_token_error

    alias_method_chain :render, :truncate_flash
  end

  def log_exception(ex)
    logger.error "Internal Server Error"
    logger.error ex.message
    logger.error clean_backtrace(ex).join("\n")
  end

  #
  # Note: When can't get token from PDC server, raise 500 error.
  # BZ: 1426057
  #
  def fetch_token_error
    redirect_to_error!("Can't fetch token from PDC server.", :internal_server_error)
  end

  #
  # NB: This actually does not redirect now.
  # See Bz 703408
  #
  def redirect_to_error!(msg, status = :not_found)
    respond_to do |format|
      format.html do
        if current_user
          #
          # Let's try just rendering an error page instead
          # instead of redirecting.
          #

          ### old way
          #flash[:error] = msg
          #redirect_to :action => :errata_error, :controller => :errata

          ### New way
          @error_message = msg
          render :file => 'errata/error_message', :status => status

        else
          render :text => "ERROR: #{msg}\n", :status => status
        end
      end
      format.text { render :text => "ERROR: #{msg}\n", :status => status }
      format.json { render :json => { :error => msg }, :status => status }
      format.js   { render :js   => { :error => msg }.to_json, :status => status }
      format.any { head status }
    end
    return false
  end

  def render_exception_message_to_client(ex)
    respond_to do |format|
      format.html do
        if current_user
          @exception = ex
          render :file => 'shared/site_messages/an_error_occurred', :status => :internal_server_error
        else
          render :text => "ERROR: #{ex.message}\n", :status => :internal_server_error
        end
      end
      format.json {
        render :json => {:error =>  "ERROR: #{ex.message}"}.to_json,
        :status => :internal_server_error
      }
      format.text { render :text => "ERROR: #{ex.message}\n", :status => :internal_server_error }
      format.any { head :internal_server_error }
    end
  end

  def route_not_found
    render :json => {:error => 'Bad URL'}.to_json, :status => :not_found
    render :text => 'URL Invalid', :status => :not_found
  end

  # Send an exception notification email so we know this happened
  def send_exception_notification(ex)
    return if Rails.env.test?
    ExceptionNotifier::Notifier.exception_notification(request.env, ex).deliver
  end

  def server_error(exception)
    log_exception exception
    send_exception_notification exception
    render_exception_message_to_client exception
  end

  TRUNCATE_FLASH_LENGTH = 1400

  # truncates long messages in flash.  Otherwise, large error messages
  # can cause ActionDispatch::Cookies::CookieOverflow, e.g. bug 1132328.
  #
  # Could be applied to flash[:notice] as well, but it's not since that
  # hasn't caused problems, and notices should be more predictable than
  # errors in general.
  #
  def render_with_truncate_flash(*args)
    [:alert, :error].each do |key|
      msg = flash[key]
      next unless msg
      next if msg.length < TRUNCATE_FLASH_LENGTH

      split_at = TRUNCATE_FLASH_LENGTH - 150
      (first,rest) = [msg[0..(split_at-1)], msg[split_at..TRUNCATE_FLASH_LENGTH]]

      Rails.logger.warn "Truncating huge flash[:#{key}]: #{first}..."

      elide_msg = "...additional messages were hidden. Too many errors to display!"

      # heuristic to try to slot the message in a sensible place.
      if rest.sub!(%r{<br[ /]*>.*$}, "<br/>#{elide_msg}")
        # slotted after an existing line
      else
        rest = "<br/>#{elide_msg}"
      end
      flash[key] = [first,rest].join
    end

    render_without_truncate_flash(*args)
  end

  # To be used with around_filter.
  #
  # If action fails with an exception from which field_errors can be
  # extracted (an ActiveModel::Errors object), and JSON/JS is
  # accepted, render the errors in the usual format:
  #
  #   {"errors": {"field1":["error", "other error"], "field2": ...}}
  #
  # ...and respond with HTTP 400.
  #
  # Otherwise, render the errors in the following format:
  #
  #   {"error": "This is an error message."}
  #
  # ...and respond with HTTP 400.
  #
  # For html request, render the error page with error messages.
  #
  # The filter has no effect for other formats, exception propagate.
  #
  # Exceptions with field_errors include ActiveRecord::RecordInvalid
  # and DetailedArgumentError.
  #
  # Non field_errors exception is ActiveRecord::RecordNotFound
  #
  def with_validation_error_rendering(opts = {})
    begin
      yield
    rescue => e
      respond_or_raise(e)
    end
  end

  # Given an error object, respond appropriately; if no appropriate response can
  # be determined, re-raise.
  def respond_or_raise(error)
    status = nil

    begin
      raise error
    rescue ActiveRecord::RecordNotFound
      status = :not_found
    rescue FetchLimitExceededError
      status = :forbidden
    rescue ActiveRecord::RecordInvalid, DetailedArgumentError
      status = :bad_request
    rescue ActionView::Template::Error
      # Any errors from within a template are wrapped in this type.
      # Dispatch based on the unwrapped type.
      # If we fail to dispatch, keep the ActionView::Template::Error object.
      begin
        return respond_or_raise(error.original_exception)
      rescue
        raise error
      end
    end

    respond_with_error(error, :status => status)
  end

  def respond_with_error(error, opts = {})
    status = opts[:status] || :bad_request
    on_error_render_page = opts[:on_error_render_page] || nil
    respond_to do |format|
      if error.respond_to?(:field_errors)
        error_fields = error.field_errors
        json_data = { :errors => error_fields }
      else
        error_fields = error.respond_to?(:message) ? error.message : error
        # We have singular :error and plural :errors here. Maybe we should only use
        # one to keep the output consistent. Not sure whether it is safe to do so
        # because it might impact the consumers.
        json_data = { :error => error_fields }
      end
      format.html do
        @error_message = error_fields.respond_to?(:full_messages) ?
          error_fields.full_messages.join("\n") :
          error_fields
        if on_error_render_page.nil?
          render :file => 'errata/error_message', :status => status
        else
          flash[:error] = @error_message
          render on_error_render_page, :status => status
        end
      end
      format.json { render(:json => json_data, :status => status) }
      format.js   { render(:json => json_data, :status => status) }
      format.all  { raise error }
    end
  end
end

# used by with_validation_error_rendering
ActiveRecord::RecordInvalid.class_eval do
  def field_errors
    self.record.errors
  end
end
