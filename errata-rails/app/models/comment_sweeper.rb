#
# Send mail after comment has committed.
# Sweepers can access web context, allowing targeted mail delivery
# based on execution context
#
# ** This broke when we upgraded to Rails 3.0.
# ** See https://bugzilla.redhat.com/show_bug.cgi?id=756585
#
class CommentSweeper < ActionController::Caching::Sweeper
  observe Comment

  def after_commit(comment)
    return if comment.disabled_notification
    begin
      mail_comment(comment)
    rescue Exception => e
      #
      # Despite how it looks we *can* end up here. Eg, if an exception is thrown inside one
      # of the rescues in mail_comment (apparently).
      #
      MAILLOG.error "Uncaught error sending comment mail: #{e.class} #{e.message}. EMAIL NOT DELIVERED!"
    end
  end

  private

  DEFAULT_DELIVERY = "errata_update"

  def mail_comment(comment)
    #
    # Get the delivery method candidate.
    #
    delivery_method = comment.respond_to?(:delivery_method) ?
      comment.delivery_method : get_delivery_method

    #
    # See if we can use it. If not then fall back to the default.
    #
    if delivery_method.blank?
      MAILLOG.debug "Can't determine a delivery method so using default"
      delivery_method = DEFAULT_DELIVERY

    elsif !Notifier.respond_to?(delivery_method)
      MAILLOG.debug "Delivery method #{delivery_method} not defined so using default"
      delivery_method = DEFAULT_DELIVERY

    else
      MAILLOG.debug "Using delivery method #{delivery_method}"

    end

    #
    # Try to send a comment mail. Do some fallback error handling in case it fails.
    #
    begin
      Notifier.send(delivery_method, comment).deliver
      log_mail_if_test_mode

    rescue NoMethodError => e
      #
      # This should be redundant since since we already
      # checked Notifier.respond_to?(delivery_method)
      #
      MAILLOG.debug "#{e.class} #{e.message} thrown so falling back to default delivery method. SHOULD NEVER HAPPEN."
      Notifier.send(DEFAULT_DELIVERY, comment).deliver
      log_mail_if_test_mode

    rescue ActionView::ActionViewError => e
      #
      # If it throws this error then we have broken mailer views for some reason.
      # (And they really should be fixed).
      # Fallback to the default email which hopefully works.
      #
      MAILLOG.debug "#{e.class} #{e.message} thrown so falling back to default delivery method. SHOULD (PROBABLY) NEVER HAPPEN."
      Notifier.send(DEFAULT_DELIVERY, comment).deliver
      log_mail_if_test_mode

    rescue Exception => e
      #
      # Possibly an SMTP timeout? Or some other error?
      # TODO: should send an email to developers when this happens so we find
      # out quickly.
      #
      MAILLOG.error "EMAIL NOT DELIVERED! #{e.class} #{e.message}"
    end
  end

  #
  # Decide what type of email we will try to send based on the controller
  # and the action (if possible). Returns nil if we can't do that.
  #
  def get_delivery_method
    if defined?(controller) && controller.present? && controller.params.present?
      controller_name = params[:controller]
      action_name     = params[:action]
      "#{controller_name}_#{action_name}"
    else
      nil
    end
  end

  #
  # You can tail -f logs/mail.log when testing and see the emails.
  #
  def log_mail_if_test_mode
    if ActionMailer::Base.delivery_method == :test
      MAILLOG.info "Mail sent:"
      MAILLOG.info ActionMailer::Base.deliveries.last
    end
  end
end
