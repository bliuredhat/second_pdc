module Jira
  JIRA_URL      = ENV['ET_DEV_RPC_JIRA_URL'] || 'https://issues-stg.jboss.org'
  JIRA_USER     = ENV['ET_DEV_RPC_JIRA_USER'] || 'admin'
  JIRA_PASSWORD = ENV['ET_DEV_RPC_JIRA_PASSWORD'] || 'admin'
end
