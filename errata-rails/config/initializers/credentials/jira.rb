module Jira
  JIRA_URL      = (Rails.env.development? && ENV['ET_DEV_RPC_JIRA_URL']) || 'http://localhost:2990/jira'
  JIRA_USER     = (Rails.env.development? && ENV['ET_DEV_RPC_JIRA_USER']) || 'admin'
  JIRA_PASSWORD = (Rails.env.development? && ENV['ET_DEV_RPC_JIRA_PASSWORD']) || 'admin'
end
