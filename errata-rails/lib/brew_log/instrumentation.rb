# This module is intended for inclusion into ActionController.
# It follows the design of similar modules shipped with rails such
# as ActionController::Instrumentation.
module BrewLog
  module Instrumentation
    extend ActiveSupport::Concern

    # Invoked when beginning to process an action
    def process_action(*args, &block)
      ::BrewLog::Subscriber.reset_runtime
      super
    end

    # Hook invoked after an action completes, used to append data to be
    # accessed during logging
    def append_info_to_payload(payload)
      payload[:brew_runtime] = ::BrewLog::Subscriber.runtime
      super
    end

    module ClassMethods
      # Called when generating the "Completed 200 OK ..." log line.
      # Expected to return an array of messages which will be included
      # in the log.
      def log_process_action(payload)
        messages = super
        if (runtime = payload[:brew_runtime]) && runtime != 0
          messages << ("Brew: %.1fms" % runtime.to_f)
        end
        messages
      end
    end
  end
end
