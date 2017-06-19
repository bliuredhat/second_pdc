require 'curb'
require 'json'
require 'lightblue/errors'


module Lightblue
  module HTTP
    module Response
      STATUS    = :status
      PROCESSED = :processed
    end

    def post(api_path, body)
      curl.url = api_url(api_path)
      curl.post_body = body
      logger.debug "POST: #{curl.url} | BODY: #{body}"
      handle_response { curl.http_post }
      json_response[Response::PROCESSED]
    end

    def errors
      @errors ||= []
    end

    private

    def json_response
      JSON.parse curl.body_str, symbolize_names: true
    rescue JSON::ParserError => e
      logger.error "Invalid JSON: #{curl.body_str}"
      raise JsonParseError, e
    end


    def handle_response
      @errors = []
      yield

      code = curl.response_code
      return if code.in?(200..399)

      logger.warn "curl: [ #{curl.url} ] returned: #{code}"

      body = curl.body_str
      error = if (title = body.match(%r{<title>(.*?)</title>}m)).present?
                title[1]
              else
                errors.last.present? ? errors.last[:msg] : "Unknown Error: #{body}"
              end

      details = {
        error: error,
        code: code,
        url: curl.url,
        body: body
      }

      logger.warn "Raising Error: [ #{curl.url} ] code: #{code}, error: #{error}"

      case code
        when 400      then raise BadRequestError, details
        when 401      then raise UnauthorizedError, details
        when 403      then raise ResourceForbiddenError, details
        when 404      then raise ResourceNotFound, details
        when 405      then raise MethodNotAllowedError, details
        when 400..499 then raise ClientError, details
        when 500..599
          # server can return json format or html. So raise
          # ApiError if the response is json
          begin
            raise ApiError, details.merge(json: JSON.parse(body))
          rescue JSON::ParserError
            raise ServerError, details
          end
        else raise ClientError, details
      end
    end

    def api_url(path)
      URI.join(data_url.sub(%r{/?$}, '/'), path).to_s
    end

    def curl
      @curl ||= begin
        curl = Curl::Easy.new(data_url) do |c|
          c.verbose = verbose
          c.follow_location = true
          c.max_redirects = 5
          c.headers['Content-Type'] = 'application/json'
          c.headers['Accept'] = 'application/json'
          c.ssl_verify_peer = ssl_verify_peer
          c.cert = File.expand_path(cert_file)
          c.cert_key = File.expand_path(cert_key_file) if cert_key_file
        end

        if verbose
          curl.on_debug do |*args|
            logger.debug args.join(' ').chomp
          end
        end

        curl.on_redirect do |_curl, code|
          logger.info "Server is redirecting: #{code.inspect}"
          errors << { :err_class => code[0], :msg => code[1] }
        end

        # 4xx errors
        curl.on_missing do |_curl, code|
          logger.warn "Resource Error: #{code.inspect}"
          errors << { :err_class => code[0], :msg => code[1] }
        end

        # 5xx errors
        curl.on_failure do |_, code|
          logger.warn "Server Error: #{code.inspect}"
          errors << { :err_class => code[0], :msg => code[1] }
        end
        curl
      end
    end

  end # HTTP
end # Lightblue
