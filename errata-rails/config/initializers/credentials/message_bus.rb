# Message bus settings.
# These settings are suitable for the development broker.
# In production, this file is expected to be eng-ops managed.
module MessageBus
  # Provide multiple URLs to support failover.
  BROKER_URL = %w[
    amqps://messaging-devops-broker01.dev1.ext.devlab.redhat.com:5671
    amqps://messaging-devops-broker02.dev1.ext.devlab.redhat.com:5671
  ]

  # cert and key should be in PEM format.
  # They can be in the same file.
  # Only the BEGIN CERTIFICATE / BEGIN RSA PRIVATE KEY blocks are used.
  CLIENT_CERT = "#{Rails.root}/cert/msg-client-errata.crt"
  CLIENT_KEY = "#{Rails.root}/cert/msg-client-errata.key"
  CERT_NAME = "msg-client-errata's Red Hat ID"

end
