# This log subscriber can be attached to Brew rpc_call events to
# instrument the RPC calls in a similar way as views and database
# queries are instrumented by default.
module BrewLog
  class Subscriber < ActiveSupport::LogSubscriber
    def self.runtime
      Thread.current[:_brew_runtime] || 0
    end

    def self.add_to_runtime(x)
      Thread.current[:_brew_runtime] = self.runtime + x
    end

    def self.reset_runtime
      Thread.current[:_brew_runtime] = 0
    end

    def rpc_call(event)
      duration = event.duration
      method = event.payload[:method]
      args = event.payload[:arguments]

      # sample output:
      # DEBUG  (2400.891ms)  Brew listTags("spicec-libs-win-0.1-4")
      debug "(#{duration}ms)  Brew #{method}(#{args.map(&:inspect).join(', ')})"

      BrewLog::Subscriber.add_to_runtime duration
    end
  end
end
