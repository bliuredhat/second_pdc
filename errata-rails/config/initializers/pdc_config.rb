PDC.configure do |pdc|
  pdc.site              = PdcConf::SITE
  pdc.requires_token    = PdcConf::REQUIRES_TOKEN
  pdc.disable_caching   = PdcConf::DISABLE_CACHING
  pdc.ssl_verify_mode   = OpenSSL::SSL::VERIFY_NONE unless PdcConf::SSL_VERIFICATION
  pdc.logger            = PDC_LOG
  pdc.log_level         = PdcConf::LOG_LEVEL
end
