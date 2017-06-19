require 'vcr'

module VCR
  CASSETTE_DIR = File.dirname(__FILE__) + "/../data/vcr"
end

VCR.configure do |c|
  # NOTE: Disable http connections by default so that connections to
  # external services are blocked in the CI environment. When
  # writing/debugging a test, set it to true to allow connections
  c.allow_http_connections_when_no_cassette = false

  # Disable recording in CI; see: jenkins/errata-tool-ruby2
  c.default_cassette_options = { record: :none } if ENV.key?('CI_MODE')

  c.ignore_localhost = true

  c.cassette_library_dir = VCR::CASSETTE_DIR
  c.hook_into :webmock

  # To enable debug logs
  # c.debug_logger = File.open('tmp/vcr.log', 'w')
  # scrub the secrets out
  c.before_record do |i|
    i.response.headers.delete('Set-Cookie')
    i.response.headers.delete('Www-Authenticate')
    i.request.headers.delete('Authorization')
    i.request.headers.delete('Token')
  end
end

module Extension
  module FixtureApi
    # For a test like below
    # class FooBarTest
    #   test 'a test procedure'
    # end
    #
    # returns 'foo_bar_test_test_a_test_procedure'
    def fixture_name
      class_name = self.class.name.underscore
      test_name = name.partition('(').first
      "#{class_name}_#{test_name}"
    end
  end

  module CassetteHelpers
    #
    # Want to provide a nicer way to specify a list of cassette files.
    # Nested use_cassette methods does that, but we don't want to see
    # deep nested blocks in our tests.
    #
    # My use case for this involves allow_playback_repeats being set so
    # let's be lazy for now and just hard code that here rather than
    # pass an options hash.
    #
    def use_multiple_cassettes(cassettes, &block)
      if cassettes.any?
        VCR.use_cassette(cassettes[0], allow_playback_repeats: true) do
          use_multiple_cassettes(cassettes[1..-1], &block)
        end
      else
        yield
      end
    end

    #
    # Find cassettes that match a given pattern by looking in the file
    # system
    #
    def find_cassettes_matching(regex)
      Dir.glob("#{VCR::CASSETTE_DIR}/*.yml").
        map{ |c| File.basename(c, '.yml') }.
        select{ |c| c.match(regex) }
    end

    #
    # For example, to use all cassette files with pdc_ceph21 in their name:
    #
    #   VCR.use_cassettes_for(:pdc_ceph21) do
    #     ...
    #   end
    #
    def use_cassettes_for(string, &block)
      use_multiple_cassettes(find_cassettes_matching(%r{#{string}}), &block)
    end

  end
end

module Test::Unit
  class TestCase
    include Extension::FixtureApi
  end
end

module VCR
  extend Extension::CassetteHelpers
end
