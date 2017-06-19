# Zabbix settings.
# These settings are suitable for the non-product envs.
# In production, this file is expected to be managed via ansible.
module Zabbix
  HOST = 'zabbix.host.stage.eng.rdu2.redhat.com'
  PORT = 10051
  # The custom hostname configured in zabbix server
  ERRATA_HOSTNAME = 'errata-web-01.host.stage.eng.bos.redhat.com'
  # The key used to gather the info of umb connection
  KEY_UMB_CONNECTION = 'errata.umb.conn'
end
