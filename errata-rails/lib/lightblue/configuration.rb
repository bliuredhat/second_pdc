module Lightblue
  module Configuration
    KEYS = [
      :data_url, :metadata_url,
      :cert_file,
      :cert_key_file,
      :ssl_verify_peer,
      :verbose,
      :logger,
    ].freeze

    attr_accessor(*KEYS)

    def self.defaults
      @defaults ||= {
        :ssl_verify_peer  => false,
        :cert_file        => '~/.errata/lightblue.pem',
        :verbose          => false,
        :logger           => Logger.new($stdout).tap { |log| log.progname = name },
      }
    end

    def options
      Hash[*KEYS.map { |k| [k, send(k)] }.flatten]
    end

  end
end
