module Lightblue

  # Base class for all Lightblue errors
  # error can be created from a string or an exception
  # that will be wrapped
  class Error < StandardError
    attr_reader :wrapped_expection

    def initialize(obj)
      return super(obj.to_s) unless obj.respond_to?(:backtrace)
      super(obj.message)
      @wrapped_expection = obj
    end

    def backtrace
      return super unless wrapped_expection
      wrapped_expection.backtrace
    end

    def inspect
      inner = inspect_inner
      return super if inner.blank?

      %(#<#{self.class}#{inner}>)
    end

    private

    def inspect_inner
      return unless wrapped_expection
      " wrapped=#{wrapped_expection.inspect}"
    end
  end

  # HTTP errors may hold details related to response in
  # the form of a Hash type (respond_to? :each_key)
  class HTTPError < Error
    attr_reader :response

    def initialize(obj)
      return super unless obj.respond_to?(:each_key)
      @response = obj
      super("server responded with code: #{@response[:code]}")
    end

    def inspect
      "#{super} response=#{response.inspect}" if response
    end
  end


  ### HTTP 4xx Errors  ###
  class ClientError < HTTPError; end

  class ConnectionFailed < ClientError; end

  class BadRequestError < ClientError; end
  class UnauthorizedError < ClientError; end
  class ResourceForbiddenError < ClientError; end
  class ResourceNotFound < ClientError; end
  class MethodNotAllowedError < ClientError; end

  ### HTTP 5xx Errors  ###
  class ServerError < HTTPError; end
  class ApiError < ServerError; end

  ### configuration errors ###
  class ConfigError < Error; end
  class CertError < ConfigError; end
  class CertKeyError < ConfigError; end

  ### JSON related
  class JsonParseError < Error; end

end
