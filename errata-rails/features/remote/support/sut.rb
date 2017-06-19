require 'yaml'

raise "TEST_ENV environment variable not exported" unless ENV['TEST_ENV']

module RemoteTest
  module Configuration
    KEYS = %i( app_host ).freeze
    attr_accessor *KEYS

    def load(test_env)
      config_file = File.expand_path('../../config/env.yml', __FILE__)
      yaml = YAML.load_file(config_file)

      conf = yaml[test_env.downcase]
      raise "Unknown TEST_ENV: #{test_env}, see: #{config_file} for valid env" unless conf
      KEYS.each { |k| send("#{k}=", conf[k.to_s]) }
    end

    extend self
  end
end

RemoteTest::Configuration.load(ENV['TEST_ENV'])
Capybara.app_host = RemoteTest::Configuration.app_host
