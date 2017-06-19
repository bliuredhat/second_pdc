# qpid message bus settings.
# In production, expected to be managed by eng-ops.
module Qpid
  HOST = 'qpid.test.engineering.redhat.com'
  PORT = 5671
  EXCHANGE = 'eso.topic'
  TOPIC_PREFIX = 'errata'

  SECURE_TOPIC_PREFIX = 'secalert.errata'

  ABIDIFF_TOPIC_PREFIX = 'abidiff.status'

  COVSCAN_TOPIC_PREFIX = 'covscan.scan'
  COVSCAN_EXCHANGE = 'eso.topic'
end
