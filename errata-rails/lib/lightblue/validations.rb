require 'lightblue/errors'

module Lightblue

  # validates the configuratiosn
  module Validations
    def validate
      raise ConfigError, data_url unless data_url =~ /\A#{URI.regexp(%w(http https))}\z/

      validate_cert
      validate_cert_key
    end

    private

    def validate_cert
      cert = File.expand_path(cert_file)
      raise CertError, "File #{cert} does not exist" unless File.file?(cert)
    end

    def validate_cert_key
      # cert_key_file is optional
      return unless cert_key_file

      key = File.expand_path(cert_key_file)
      raise CertKeyError, "File #{key} does not exist" unless File.file?(key)
    end
  end

end
