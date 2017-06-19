module ActionMailer #:nodoc:
  class Base
    ALWAYS_RAISE_ACTIONS = ['request_rhnlive_push']
    # Re-define deliver! to actually log errors even if raise_delivery_errors == false
    def deliver!(mail = @mail)
      raise "no mail object available for delivery!" unless mail
      unless logger.nil?
        logger.info  "Sent mail to #{Array(recipients).join(', ')}"
        logger.debug "\n#{mail.encoded}"
      end

      begin
        __send__("perform_delivery_#{delivery_method}", mail) if perform_deliveries
      rescue Exception => e  # Net::SMTP errors or sendmail pipe errors
        logger.error "#{delivery_method} delivery Error! #{e.message}" unless logger.nil?
        raise e if raise_delivery_errors || ALWAYS_RAISE_ACTIONS.include?(self.action_name)
      end
      return mail
    end

  end
end
