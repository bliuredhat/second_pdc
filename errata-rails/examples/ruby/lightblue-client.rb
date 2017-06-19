#! /usr/bin/env ruby

# This a test script to verify that the lightblue client works
# Usage: ./examples/ruby/lightblue-client.rb

$LOAD_PATH.unshift File.expand_path('../../../lib', __FILE__)

require File.expand_path('../../../config/application', __FILE__)
require 'lightblue'

LIGHTBLUE_LOG = Logger.new($stderr)

module LB
  # Lightblue servers
  # -----------------------------------------------
  # DEV0  https://datasvc.lightblue.dev0.redhat.com
  # DEV1  https://datasvc.lightblue.dev1.redhat.com
  # DEV2  https://datasvc.lightblue.dev2.redhat.com
  # QA    https://datasvc.lightblue.qa.redhat.com
  # STAGE https://datasvc.lightblue.stage.redhat.com
  # PROD  https://datasvc.lightblue.corp.redhat.com
  #
  # source:  https://mojo.redhat.com/docs/DOC-1036796

  CERT_DIR = File.expand_path('~/.errata/certs/')

  # Legacy cert without any key
  DEV_2_OLD = {
    data_url:      'https://datasvc.lightblue.dev2.redhat.com/rest/data',
    cert_file:     File.join(CERT_DIR, "lb-#{ENV['USER']}.pem"),
  }.freeze

  # new certs have crt and key
  DEV_2 = {
    data_url:      'https://datasvc.lightblue.dev2.redhat.com/rest/data',
    cert_file:     File.join(CERT_DIR, "lb-#{ENV['USER']}.crt.pem"),
    cert_key_file: File.join(CERT_DIR, "lb-#{ENV['USER']}.key.pem"),
  }.freeze

  QA = {
    data_url:      'https://datasvc.lightblue.qa.redhat.com/rest/data',
    cert_file:     File.join(CERT_DIR, "lb-errata-qe.crt.pem"),
    cert_key_file: File.join(CERT_DIR, "lb-errata-qe.key.pem"),
  }.freeze

  STAGE = {
    data_url:      'https://datasvc.lightblue.stage.redhat.com/rest/data',
    cert_file:     File.join(CERT_DIR, "lb-errata-stage.crt.pem"),
    cert_key_file: File.join(CERT_DIR, "lb-errata-stage.key.pem"),
  }.freeze

  PROD = {
    data_url:      'https://datasvc.lightblue.corp.redhat.com/rest/data/',
    cert_file:     File.join(CERT_DIR, "lb-errata-prod.crt.pem"),
    cert_key_file: File.join(CERT_DIR, "lb-errata-prod.key.pem"),
  }.freeze

end

module LightblueConf
  VALUES = LB::DEV_2.merge(log_level: :debug)
end

def main
  puts "Using ruby: #{RUBY_VERSION}"
  puts "Config: %p \n\n" % LightblueConf::VALUES

  client = Lightblue::ErrataClient.new

  nvra = client.container_image.nvra_for_brew_build('rh-ror41-docker-4.1-13.1')
  puts "NVRA: #{nvra.class} length: #{nvra.length}"
  puts "First record:"
  p nvra.first
rescue Lightblue::Error => e
  p e
end

main if __FILE__ == $PROGRAM_NAME
