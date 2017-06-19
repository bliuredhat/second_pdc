# Dummy Config - cfengine managed
# (Or use the environment vars in your local devel environment)
module Bugzilla
  dev_or_test =  Rails.env.development? || Rails.env.test?
  BUGZILLA_SERVER   = (dev_or_test && ENV['ET_DEV_RPC_BUGZILLA_SERVER'  ]) || 'theserver'
  BUGZILLA_USER     = (dev_or_test && ENV['ET_DEV_RPC_BUGZILLA_USER'    ]) || 'theuser'
  BUGZILLA_PASSWORD = (dev_or_test && ENV['ET_DEV_RPC_BUGZILLA_PASSWORD']) || 'thepasswd'
end
