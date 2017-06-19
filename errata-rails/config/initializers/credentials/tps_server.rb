# Could be cfengine managed if required, though currently it is not.
# Can also use an environment var in your local devel environment.
# (wormtail is John Lockhart's current devel server).
module Tps
  #TPS_SERVER = 'wormtail.bos.redhat.com'
  TPS_SERVER = (Rails.env.development? && ENV['ET_TPS_SERVER']) || 'tps-server.lab.bos.redhat.com'
end
