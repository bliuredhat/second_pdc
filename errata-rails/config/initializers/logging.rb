TPSLOG = ErrataLogger.new('tps')
RPCLOG = ErrataLogger.new('xmlrpc')
BUGLOG = ErrataLogger.new('bugzilla')
ORGCHARTLOG = ErrataLogger.new('orgchart')
BREWLOG = ErrataLogger.new('brew', :level => Logger::DEBUG)
JIRALOG = ErrataLogger.new('jira')
RHNLOG = ErrataLogger.new('rhn')
MAILLOG = ErrataLogger.new('mail', :level => Logger::DEBUG)
MBUSLOG = ErrataLogger.new('mbus', :level => Logger::DEBUG)
ASYNC_LOG = ErrataLogger.new('async')
KERB_RPC_LOG = ErrataLogger.new('kerbrpc')
ADMIN_AUDIT_LOG = ErrataLogger.new('admin_audit')
REQUESTS_LOG = ErrataLogger.new('requests')
PDC_LOG = ErrataLogger.new('pdc')
LIGHTBLUE_LOG = ErrataLogger.new('lightblue')
ZABBIX_LOG = ErrataLogger.new('zabbix')

begin
  BUGRECON = ErrataLogger.new('bugreconcile')
rescue Errno::EACCES => e
  # Ignore permissions error due to cron job running.
end

# add the Brew runtime alongside Views, ActiveRecord runtime
BrewLog::Subscriber.attach_to :brew
ActionController::Base.class_eval do
  include BrewLog::Instrumentation
end
