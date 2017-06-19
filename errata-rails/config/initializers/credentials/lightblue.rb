module LightblueConf
  # see: lib/lightblue/configuration.rb for all keys
  VALUES = {
    :data_url  => 'https://datasvc.lightblue.dev2.redhat.com/rest/data',
    :cert_file => '~/.errata/lightblue.pem',
    :ssl_verify_peer => false,
  }.freeze
end
