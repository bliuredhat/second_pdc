require File.expand_path('../../../../config/application', __FILE__)

# Message bus settings.
# https://mojo.redhat.com/docs/DOC-1048438
module MessageBus
  CERT_DIR = File.expand_path('~/.errata/certs/')
  APP = "msg-client-errata"

  puts "UMB test on env: #{Rails.env}"

  if Rails.env.development?
    BROKER_URL = %w[
      amqps://messaging-devops-broker01.dev1.ext.devlab.redhat.com:5671
      amqps://messaging-devops-broker02.dev1.ext.devlab.redhat.com:5671
    ]
    CLIENT_CERT = File.join(CERT_DIR, "#{APP}-dev.crt")
    CLIENT_KEY = File.join(CERT_DIR, "#{APP}-dev.key")
    CERT_NAME = "#{APP}'s Red Hat ID #3"
  elsif Rails.env.test?
    BROKER_URL = %w[
      amqps://messaging-devops-broker01.web.qa.ext.phx1.redhat.com:5671
      amqps://messaging-devops-broker02.web.qa.ext.phx1.redhat.com:5671
    ]
    CLIENT_CERT = File.join(CERT_DIR, "#{APP}-qa.crt")
    CLIENT_KEY = File.join(CERT_DIR, "#{APP}-qa.key")
    CERT_NAME = "#{APP}'s Red Hat ID"
  elsif Rails.env.staging?
    BROKER_URL = %w[
      amqps://messaging-devops-broker01.web.stage.ext.phx2.redhat.com:5671
      amqps://messaging-devops-broker02.web.stage.ext.phx2.redhat.com:5671
    ]
    CLIENT_CERT = File.join(CERT_DIR, "#{APP}-stage.crt")
    CLIENT_KEY = File.join(CERT_DIR, "#{APP}-stage.key")
    CERT_NAME = "#{APP}'s Red Hat ID #2"
  elsif Rails.env.production?
    BROKER_URL = %w[
      amqps://messaging-devops-broker01.web.prod.ext.phx2.redhat.com:5671
      amqps://messaging-devops-broker02.web.prod.ext.phx2.redhat.com:5671
    ]
    CLIENT_CERT = File.join(CERT_DIR, "#{APP}-prod.crt")
    CLIENT_KEY = File.join(CERT_DIR, "#{APP}-prod.key")
    CERT_NAME = ""
  else
    raise "Env not supported."
  end
end