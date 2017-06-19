require 'curb'
require 'xmlrpc/parser'
require 'xmlrpc/create'
require 'xmlrpc/config'
require 'xmlrpc/utils'

module XMLRPC
  class KerberosClient
    include ParserWriterChooseMixin
    include ParseContentType
    class ResponseNotOkay < ::RuntimeError; end

    attr_reader :url

    def initialize(url, opts={})
      @url = url
      @namespace = opts[:namespace]
      @debug = opts[:debug]
      @verbose = opts[:verbose]

      @curl = ::Curl::Easy.new(@url) do |c|
        c.http_auth_types = ::Curl::CURLAUTH_GSSNEGOTIATE
        c.userpwd = ':'

        # In case you want to add extra curl config
        yield(c) if block_given?

        # `c.verbose = true` here would send the debug messages to STDERR so instead define our own handler to log them.
        # (Note that we don't log the request and response below when verbose is on because they're already being logged).
        c.on_debug { |info_type, info_text| do_log("#{KerberosClient.curl_info_type_lookup(info_type)} #{info_text}") } if @verbose
      end

      @opts = opts
    end

    def refresh_credentials
      KerbCredentials.refresh
    end

    # Define a XMLRPC::FooClient.instance to reuse the same client instance conveniently.
    # Warning: Notice that the opts have no effect after the first time this is called!
    def self.inherited(subclass)
      subclass.instance_eval do
        def instance(opts={})
          @_instance ||= self.new(opts)
        end
      end
    end

    def method_missing(method_name, *args)
      # Prepend dot-delimited method namespace if present
      method_name = "#{@namespace}.#{method_name}" if @namespace

      # Prepare request
      request = create().methodCall(method_name, *args)
      do_log("Request #{request}") unless @verbose

      # Send request and read response
      data = nil
      is_ok, response = begin
        refresh_credentials
        @curl.http_post(request)
        data = @curl.body_str
        do_log("Response #{data}") unless @verbose

        # Parse response and return.
        # This returns an array of two items, ie [is_ok, response]
        parser().parseMethodResponse(data)
      rescue StandardError => e
        # This will set is_ok to nil and response to the
        # exception message then rethrow ResponseNotOkay.
        # (This is a bit scrappy but the idea is that in the higher
        # level code you only have to catch ResponseNotOkay).
        #
        # Todo: should use status code instead of this hack to show more
        # useful message when there's a kerberos problem. Actually I tried
        # to use the status code but it was giving me unexpected results,
        # maybe due to the way that gss negotiate works (?).
        [false, (data =~ /<title>401 Auth/i ? 'Authentication failure' : e.message)]
      end
      raise ResponseNotOkay.new(response.to_s) unless is_ok
      response
    end

    def do_log(message)
      log_text = "#{self.class.name} #{message}"
      KERB_RPC_LOG.info(log_text) if defined?(KERB_RPC_LOG)
      puts log_text if @debug
    end

    def self.curl_info_type_lookup(code)
      (@_info_codes||=Hash[Curl.constants.grep(/^CURLINFO_/).map{|c|[Curl.const_get(c),c]}])[code] # ;]
    end

  end

end
