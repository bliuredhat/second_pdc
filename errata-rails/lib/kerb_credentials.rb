#
# Try to prevent lib/xmlrpc/kerberos_client from using stale
# kerberos credentials. See Bug 973557.
#
# Notes:
# - I'm not sure if this is the best way to do it.
# - Should probably detect stale credentials and only
#   refresh if required. Since the connections are fairly
#   infrequent it should be okay though.
# - Could separate the host/service/keytab settings and
#   pass them in as parameters, but never mind for now.
# - The gssapi gem should allow a less hacky verson of this
#   that doesn't use /usr/bin/kinit. The @gssapi commentary
#   refers to that.
#
class KerbCredentials
  # (Unfortunatly the settings are different depending on the host)

  KERB_SERVICE = 'errata'
  HOSTNAME = `/bin/hostname`.chomp

  # Since moved to PDI, prod only uses beehive and all other hosts
  # including stage uses hostname as KERB_HOST
  KERB_HOST = Settings.errata_kerb_host || case HOSTNAME
  when 'errata-web-01.host.prod.eng.bos.redhat.com'
    'beehive'
  else
    HOSTNAME
  end

  # Since moved to PDI, all the hosts uses /etc/errata/errata.keytab
  KEYTAB = '/etc/errata/errata.keytab'

  def initialize
    # In future something like this:
    #@gssapi = GSSAPI::Simple.new(KERB_HOST, KERB_SERVICE, KEYTAB)
  end

  # Don't want to introduce a dependency on rails here so we'll check the environment var directly
  def is_production_or_staging?
    ENV['RAILS_ENV'].in?('production', 'staging')
  end

  def refresh_credentials
    return unless is_production_or_staging?

    # In future something like this:
    #@gssapi.acquire_credentials
    #@gssapi.init_context

    # kinit version:
    `/usr/bin/kinit -kt #{KEYTAB} #{KERB_SERVICE}/#{KERB_HOST}@REDHAT.COM`
  end

  def self.instance
    @@_kerb_credentials ||= KerbCredentials.new
  end

  def self.refresh
    KerbCredentials.instance.refresh_credentials
  end
end
