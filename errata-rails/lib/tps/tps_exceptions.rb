module Tps
  class TpsStandardError < StandardError
    def initialize(dist, message = nil)
      @dist = dist.to_sym

      if @dist == :rhn
        @repo_type = "RHN Channel"
      elsif @dist == :cdn
        @repo_type = "CDN Repository"
      else
        raise ArgumentError, "'#{@dist}' is not a valid push type supported by TPS"
      end

      @message = message.is_a?(Proc) ? message.call(@repo_type) : message
      super(@message)
    end

    def repo_type
      @repo_type
    end
  end

  class NoApplicableRepositoryError < TpsStandardError
    def message
      (@message) ? super : "No #{self.repo_type} is applicable to this advisory"
    end
  end

  class PushTypeNotSupportedError < TpsStandardError
    def message
      (@message) ? super : "This advisory doesn't support #{@dist.to_s.upcase} push"
    end
  end

  class PushTypeDisabledError < TpsStandardError
    def message
      (@message) ? super : "#{@dist.to_s.upcase} push is disabled in Errata Tool"
    end
  end

  class TpsSchedulingDisabledError < TpsStandardError
    def initialize(dist, repo_list, message = nil)
      @repo_list = Array.wrap(repo_list)
      super(dist, message)
    end

    def list_repos
      @repo_list
    end
  end

  class TpsStreamStandardError < StandardError
    def initialize(name, message = nil)
      @name = name
      @message = message
      super(@message)
    end
  end

  class TpsStreamTypeNotFound < TpsStreamStandardError
    def message(html = false)
      server = html ? ActionController::Base.helpers.link_to("TPS server", "http://#{Tps::TPS_SERVER}/stream_types", :target=>'_blank') : "TPS Server"
      (@message) ? super : "type '#{@name}' does not exist in #{server}."
    end
  end

  class TpsVariantNotFound < TpsStreamStandardError
    def message(html = false)
      server = html ? ActionController::Base.helpers.link_to("TPS server", "http://#{Tps::TPS_SERVER}/variants", :target=>'_blank') : "TPS Server"
      (@message) ? super : "variant '#{@name}' does not exist in #{server}."
    end
  end

  class TpsStreamNotActive < TpsStreamStandardError
    def message(html = false)
       server = html ? ActionController::Base.helpers.link_to("TPS server", "http://#{Tps::TPS_SERVER}/streams", :target=>'_blank') : "TPS Server"
      (@message) ? super : "'#{@name}' is disabled in #{server}."
    end
  end

  class TpsStreamNotFound < TpsStreamStandardError
    def message(html = false)
      server = html ? ActionController::Base.helpers.link_to("TPS server", "http://#{Tps::TPS_SERVER}/streams", :target=>'_blank') : "TPS Server"
      (@message) ? super : "'#{@name}' not found in #{server}. Hence no stable systems to run TPS tests."
    end
  end
end
