#
# These are defaults for the rails-settings plugin.
# The plugin will read settings from the database. Values in
# the database can over-ride these.
#
Settings.defaults.merge!({
  #
  # Settings for Abidiff
  #
  :abidiff_url => 'SET_ABIDIFF_URL',

  :bugzilla_dirty_update_delay => 1.minutes,
  :jira_dirty_update_delay => 1.minutes,

  #
  # Settings for Bugzilla and JIRA sync via unified message bus.
  #
  # Whether the sync is enabled.
  # NOTE: if true, the usual BZ/JIRA polling happens much less often.
  #
  :mbus_bugzilla_sync_enabled => false,
  :mbus_jira_sync_enabled => false,

  #
  # The prefix for devops Virtual topic
  #
  :mbus_eng_topic => "topic://VirtualTopic.eng.",

  #
  # Settings for message switch on destination.
  #
  # NOTE: During the Qpid to UMB transition period,
  # ET need to write messages to both Qpid and UMB.
  #
  :messages_to_qpid_enabled => true,
  :messages_to_umb_enabled => true,

  #
  # The address (within the broker) to which we'll subscribe, in qpid-proton's
  # format.
  #
  :mbus_bugzilla_address => 'queue://errata_from_esb',
  :mbus_jira_address => 'queue://errata_from_esb',

  #
  # The properties used to identify messages.
  #
  # These can be left empty if each message type goes to a different address,
  # but should be filled in if multiple types of messages are being delivered to
  # the same address.
  #
  # NOTE: only supports exact matches, only supports `AND' semantics.
  #
  :mbus_bugzilla_properties => {'esbSourceSystem' => 'bugzilla',
                                'esbMessageType' => 'bugzillaNotification'},
  :mbus_jira_properties => {'esbSourceSystem' => 'jbossJira',
                            'esbMessageType' => 'jbossJiraNotification'},

  #
  # How often we need to call `work' on the messenger, to handle heartbeats
  # and similar events.
  #
  # This _should_ be determined dynamically, but due to bug
  # https://issues.apache.org/jira/browse/PROTON-512 , the appropriate value
  # can't be queried using the messenger API, so we'll make it a setting.
  #
  :mbus_work_interval => 10.seconds,

  #
  # Settings for Covscan
  #
  :covscan_xmlrpc_url => 'https://uqtm.lab.eng.brq.redhat.com/covscanhub/xmlrpc/kerbauth/',

  #
  # Settings for JIRA
  #
  :jira_closed_status => 'Closed',
  :jira_closed_resolution => 'Done',
  :jira_security_label => 'Security',
  :jira_public_comment_visibility => nil,
  :jira_private_comment_visibility => {:type => 'group', :value => 'JBoss Employee'},

  # This setting restricts the usage of JIRA with ET to private issues only.
  #
  # If true:
  #  - public JIRA issues can't be filed on an advisory
  #  - an advisory with any public JIRA issues can't be shipped
  #  - all JIRA issues are not displayed in advisory XML, OVAL or text
  #
  :jira_private_only => false,

  # This setting causes JIRA issue URLs to be included in advisory references
  # (list of URLs) rather than including full JIRA issue metadata.
  # This allows RHN and other ET data consumers to handle JIRA issue references
  # as plain URLs until they are updated to fully utilize JIRA metadata.
  #
  # Affects at least:
  #  - advisory XML and OVAL views
  #  - metadata pushed to pub
  #
  :jira_as_references => true,

  # This is a mapping from security level name to type.  It is used to initialize
  # the type for newly discovered security levels.  The type of an existing
  # security level is always taken direct from the DB.
  :jira_security_level_effects => {
    'None' => 'PUBLIC',
    'Public' => 'PUBLIC',
    'JBoss Internal' => 'PRIVATE',
    'JBoss Customer' => 'PRIVATE',
    'JBoss Partner' => 'PRIVATE',
    'Red Hat Internal' => 'PRIVATE',
    'Security Issue' => 'SECURE',
  },

  #
  # See bug 1060331
  #
  :build_msgs_include_files => true,

  #
  # I want to show different labels in the banner based on the hostname, accessed
  # via request.env['SERVER_NAME']. The idea is so you can more easily tell what
  # environment you are looking at.
  #
  :host_based_banner_labels => {
    'abidiff.errata-devel.app.eng.bos.redhat.com' => 'ABIDIFF',
    'errata-devel.app.eng.bos.redhat.com'         => 'DEVSTAGE',
    'errata-stage.app.eng.bos.redhat.com'         => 'STAGE',
  },

  #
  # Similar but using Rails.env
  #
  :env_based_banner_labels => {
    'development' => 'LOCAL', # (avoid similarity with DEVSTAGE I guess)
    'test'        => 'TEST',
  },

  #
  # See Bug 789905.
  #
  # Stop showing the FTP urls for SRPMs.
  #
  # Used in errata_text.rhtml, errata_xml.rhtml and docs/show.rhtml.
  #
  :suppress_srpm_ftp_url => true,
  :suppress_gpg_message  => false,

  #
  # Errata help email
  #
  :errata_help_email => 'errata-requests@redhat.com',

  #
  # Address for rpmdiff requests
  #
  :rpmdiff_requests_email => 'rpmdiff-requests@redhat.com',

  #
  # Show the sql and form params in advisory lists
  # Usually off. Only for debugging.
  #
  :show_errata_filter_debug => false,

  #
  # Only shorten bug/build lists if errata has this many or more bugs/builds
  #
  :shorten_bug_list_threshold => 12,
  :shorten_builds_list_threshold => 20,

  #
  # When shortening a bug/build list, show this many bugs/builds
  #
  :shorten_bug_list_length => 5,
  :shorten_builds_list_length => 10,

  #
  # Never render more than this number of items when processing a
  # filter.  (Use pagination instead.)
  #
  :max_filter_items => 1000,

  #
  # Never return more than this number of items from get_advisory_list
  # XML-RPC method.
  # (A lower maximum may be applied, depending on what was requested.)
  #
  :max_advisory_list_items => 8000,

  #
  # Defines the colorscheme
  #
  :default_color_scheme => 'red',

  #
  # As defined by the ESO theme
  #
  :all_color_schemes => %w[red teal green blue orange yellow lightgray gray darkgray purple pink brown],
  :enable_xmas_scheme => false,

  #
  # Default bogus pub targets for dev/test, see overrides for staging and production below
  #
  :pub_push_targets => {
    :rhn_stage    => { :target => 'webdev' },
    :rhn_live     => { :target => 'webdev' },
    :ftp          => { :target => 'webdev' },
    :cdn          => { :target => 'webdev' },
    :cdn_stage    => { :target => 'webdev' },
    :altsrc       => { :target => 'altsrctest' },
    :cdn_docker   => { :target => 'webdev' },
    :cdn_docker_stage => { :target => 'webdev' },

    # These hss targets are defunct and should be removed at some point
    :hss_validate => { :target => 'webdev' },
    :hss_prod     => { :target => 'webdev' },
  },

  #
  # Targets for which multipush may be used (multiple errata submitted in single
  # pub task).
  #
  # This is combined with a runtime check on the pub server itself.
  #
  :pub_use_multipush => [
    :rhn_stage,
    :rhn_live,
    :cdn_stage,
    :cdn,
  ],

  # Hardcode temparily, consider to get it through PDC's API in the future
  # Need to discuss with RCM guys how to save push targets using PDC's release API.
  # The jira issue is https://projects.engineering.redhat.com/browse/PDC-1895
  # Will be removed in the future
  :pdc_push_target_names => %w[
    rhn_stage
    rhn_live
    cdn_stage
    cdn
    ftp
    altsrc
  ],

  #
  # Used to enable TPS testing for cdn content
  #
  :enable_tps_cdn => true,

  #
  # How often do we move appropriate REL_PREP jobs to PUSH_READY?
  #
  :rel_prep_to_push_ready_interval => 1.hour,

  #
  # Can set this if you want bug links to go to your qe/test/stage bugzilla server,
  # (otherwise bug links will go to the production bugzilla).
  #
  :non_prod_bug_links => false,

  #
  # Used for fetching content for the rss widget
  :news_rss_url => 'https://docs.engineering.redhat.com/createrssfeed.action?types=blogpost&labelString=errata-tool&sort=created&maxResults=20&timeSpan=2000',
  # Link to view announcements
  :news_url => 'https://docs.engineering.redhat.com/display/HTD/Errata+Tool+Announcements',

  #
  # Syncing Bugs with Bugzilla FAQ
  #
  :syncing_bugs_faq_url => 'https://docs.engineering.redhat.com/x/UZSNAQ',

  #
  # PDC integration info urls
  #
  :pdc_integration_info_url => 'https://docs.google.com/document/d/1jaJRnlAHbbJQdVfURXZgZ-dw8M8IiHwnYyEP1PU8Bks/edit',
  :pdc_ceph_mvp_info_url => 'https://docs.engineering.redhat.com/x/kYFGAg',

  #
  # Log curl debug messages to log/kerbrpc.log. (See Bug 973557).
  #
  :verbose_curl_logging => true,

  # Default year secalert starts generating CPE data
  # from the errata system. At present, they only fetch 2010
  # onwards and manually handle earlier data, as it is less
  # clearly defined
  :secalert_cpe_starting_year => 2010,

  # Realm appended to REMOTE_USER if needed.
  # Kerb appends this already.  Other auth methods such as LDAP don't.
  :remote_user_realm => 'redhat.com',

  # Used for OrgChart sync.
  # (Seems like this doesn't currently work.
  # I get 'Exception: method "OrgChart.getOrgChart" is not supported')
  :orgchart_xmlrpc_url => 'https://orgchart-test.eng.bne.redhat.com/orgchart-xmlrpc2/',

  :brew_base_url => 'https://brewweb.engineering.redhat.com/brew',
  :brew_xmlrpc_url => 'http://brewhub.engineering.redhat.com/brewhub',

  # RCM's API mentioned here: https://mojo.redhat.com/docs/DOC-988673
  # We want to use this for the API described in bug 1170398, but that
  # is not yet implemented in any environment, so this defaults to a
  # mock server.  See test/mock-server for the necessary scripts to
  # launch the mock server.
  :manifest_api_url => 'http://localhost:8889/rcm',

  # True if we should try to make use of this API.
  # Currently used for non-RPM listings only.
  :manifest_api_enabled => false,

  # True if we should warn about non-RPMs not actually able to be
  # pushed. Set to false when pub is ready.
  :show_nonrpm_warning => true,

  # URL explaining product signing keys
  :sig_keys_url => 'https://access.redhat.com/security/team/key/',

  # URL sprintf template for CVE details
  :cve_url => 'https://access.redhat.com/security/cve/%s',

  :tps_no_blocking_info_links => {
    'RHEL-7.2.0' => 'http://wiki.test.redhat.com/RhelQe/Rhel72/TpsRhnQa',
  },

  # See bug 1188483
  :ppc64le_build_pair_explanation => <<-'eos',
In most cases, non-ppc64le builds in a RHEL-7.1 advisory should be
accompanied by a corresponding ppc64le build.  There are some exceptions.
<br/>
For more information please read the <a href="http://etherpad.corp.redhat.com/rhel7-1-ppc64le-faq">RHEL 7.1 and ppc64le FAQ</a>.
If you are uncertain whether ppc64le builds should be added, please ask on <a href="mailto:ppc64le-list@redhat.com">ppc64le-list@redhat.com</a>,
or create a support ticket at <a href="mailto:release-engineering@redhat.com">release-engineering@redhat.com</a>.
eos

  :ppc64le_product_version_map => {
    'RHEL-7.1.Z' => 'RHEL-LE-7.1.Z',
    'RHEL-7.1.Z-Supplementary' => 'RHEL-LE-7.1.Z-Supplementary',
    'RHEL-7.1-EUS' => 'RHEL-LE-7.1-EUS',
  },

  # See bug 1210566
  :aarch64_build_pair_enabled => false,
  :aarch64_build_pair_explanation => <<-'eos',
In most cases, non-aarch64 builds in a RHEL-7.1.Z advisory should be
accompanied by a corresponding aarch64 build.  There are some exceptions.
<br/>
If you are uncertain whether aarch64 builds should be added, please ask
<a href="mailto:release-engineering@redhat.com">release-engineering@redhat.com</a> for advice.
eos

  :aarch64_product_version_map => {
    'RHEL-7.1.Z' => 'RHELSA-7.1.Z',
    'RHEL-7.1.Z-Supplementary' => 'RHELSA-7.1.Z-Supplementary',
  },

  :autowaive_create_roles => %w[ secalert releng admin devel ],
  :autowaive_edit_roles   => %w[ secalert releng admin devel ],
  :autowaive_manage_roles => %w[ secalert releng admin ],

  #
  # Patterns used to set reboot_suggested based on included packages.
  # All patterns are implicitly anchored.
  # See bug 1113061.
  #
  :reboot_suggested_patterns => [
    # product, rhel version,   package
    [ 'RHEL',  'RHEL-[567].*', 'kernel' ],
    [ 'RHEL',  'RHEL-5.*',     'kernel-(smp|PAE|xen)' ],

    [ 'RHEL',  'RHEL-[567].*', 'glibc' ],

    [ 'RHEL',  'RHEL-[56].*',  'hal' ],

    [ 'RHEL',  'RHEL-6.*',     '.*-firmware' ],

    [ 'RHEL',  'RHEL-7.*',     'linux-firmware' ],

    [ 'RHEL',  'RHEL-7.*',     'systemd' ],
    [ 'RHEL', ' RHEL-7.*',     'udev' ],
  ],

  #
  # If an advisory moves to QE and currently does not permit partner access, it
  # will be periodically rechecked at this interval to see if access has become
  # permitted.
  #
  :partner_notify_check_interval => 6.hours,

  #
  # CCAT messages are expected on this exchange and topic.
  #
  :qpid_ccat_exchange => 'eso.topic',
  :qpid_ccat_topic => 'content-testing.testing-event',

  #
  # CCAT results are not expected earlier than this
  # (used to hide some parts of CCAT UI for older errata)
  #
  :ccat_start_time => '2016-02-01'.to_datetime,

  #
  # Template URL for display of RT ticket links
  #
  :rt_ticket_url => 'https://engineering.redhat.com/rt/Ticket/Display.html?id=%d',

  #
  # Template URL for display of JIRA issue links from CCAT
  #
  :rcm_jira_issue_url => 'https://projects.engineering.redhat.com/browse/%s',

  #
  # If true, some errata will be pre-pushed to live targets when they're pushed to stage
  # to reduce live push time (see bug 912868).
  #
  :use_prepush => true,

  #
  # How often do we trigger pre-push jobs on eligible errata?
  #
  :prepush_trigger_interval => 6.hours,

  #
  # Default mount point to be used as brew root. This path will be used as a
  # prefix to brew rpm files such as:
  # '/mnt/redhat/brewroot/packages/nspr/4.10.8/1.el7/data/signed/fd431d51/i686/nspr-4.10.8-1.el7_1.i686.rpm'
  #
  :brew_top_dir => '/mnt/redhat/brewroot',

  #
  # See lib/kerb_credentials
  #
  :errata_kerb_host => nil,

  #
  # For end-to-end live testing, add this value to the current year when
  # generating the live id, to avoid gaps in sequence for real advisories
  #
  :end_to_end_test_year_offset => 6000,

  #
  # Short names of products used for end-to-end test advisories
  #
  :end_to_end_test_products => [
    'release-e2e-test',
  ],

  #
  # Default signing key for new product versions
  #
  :default_signing_key => 'redhatrelease2',

  #
  # Material keys for errata message
  #
  :message_material_keys => {
    'errata.bugs.changed'     => %w(who),
    'errata.builds.changed'   => %w(who added removed),
    'errata.activity'         => %w(who release errata_status synopsis from to fulladvisory)
  },

  #
  # If the ftp.redhat.com repos are missing then we'll get errors trying to add builds
  # or push to RHN. Make it easy to ignore the missing repos for development vpurposes.
  # Beware it will use some bogus ftp path instead of a real one. See lib/push/ftp.rb.
  #
  :ignore_missing_pdc_ftp_repos => false,

})


#
# These settings can be set differently for different environments.
# They should override settings above (since this merge is second, it
# will overwrite.
#
Settings.defaults.merge!({

  #------------------------------------------------------------------------------------
  :development => {
  #------------------------------------------------------------------------------------
    # Turn this on if you want to debug advisory filters
    :show_errata_filter_debug => false,

    # Appears in header near app name
    :env_indicator_text => 'DEVEL',

    # Different colour for main nav bar
    :default_color_scheme => 'orange',

    # See User.fake_devel_user and ApplicationController#check_user_auth
    :fake_devel_login_name => 'errata-test@redhat.com',

    :enable_tps_cdn => true,

    :aarch64_build_pair_enabled => true,
  },

  #------------------------------------------------------------------------------------
  :test => {
  #------------------------------------------------------------------------------------
    # Appears in header near app name
    :env_indicator_text => 'TEST',

    # tests use the normal case (JIRA fully functional) unless they
    # specifically set otherwise
    :jira_private_only => false,
    :jira_as_references => false,

    # Do not permit connection to real brew from autotests by default
    :brew_xmlrpc_url => 'http://brew-is-disabled.test.redhat.com/brew',

    # Use an older start time when testing because most fixture data is
    # artificially old
    :ccat_start_time => '2012-01-01'.to_datetime,
  },

  #------------------------------------------------------------------------------------
  :staging => {
  #------------------------------------------------------------------------------------
    :abidiff_url => 'https://abidiff-stage-01.app.eng.bos.redhat.com/job/',

    :pub_push_targets => {
      :rhn_stage    => { :target => 'rhn-stage-qa' },
      :rhn_live     => { :target => 'rhn-qa' },
      :ftp          => { :target => 'ftp-qa' },
      :cdn          => { :target => 'cdn-qa' },
      :cdn_stage    => { :target => 'cdn-stage-qa' },
      :altsrc       => { :target => 'altsrc-qa' },
      :cdn_docker   => { :target => 'cdn-docker-qa' },
      :cdn_docker_stage => { :target => 'cdn-docker-stage-qa' },

      # These hss targets are defunct and should be removed at some point
      :hss_validate => { :target => 'webdev' },
      :hss_prod     => { :target => 'webdev' },
    },

    # Appears in header near app name
    :env_indicator_text => 'STAGING',

    # Different colour for main nav bar
    :default_color_scheme => 'orange',

    # Link to the configured instance of bz for QE and stage servers
    :non_prod_bug_links => true,
  },

  #------------------------------------------------------------------------------------
  :production => {
  #------------------------------------------------------------------------------------
    :abidiff_url => 'https://abidiff-01.app.eng.bos.redhat.com/job/',
    :orgchart_xmlrpc_url => 'https://people.engineering.redhat.com/orgchart-xmlrpc2/',
    :covscan_xmlrpc_url => 'http://cov01.lab.eng.brq.redhat.com/covscanhub/xmlrpc/kerbauth/',

    # Production push targets
    :pub_push_targets => {
      :rhn_stage    => { :target => 'code-stage' },
      :rhn_live     => { :target => 'live' },
      :ftp          => { :target => 'ftp.redhat.com' },
      :cdn          => { :target => 'cdn-live' },
      :cdn_stage    => { :target => 'cdn-stage' },
      :altsrc       => { :target => 'altsrc' },
      :cdn_docker   => { :target => 'cdn-docker-prod' },
      :cdn_docker_stage => { :target => 'cdn-docker-stage' },

      # These hss targets are defunct and should be removed at some point
      :hss_validate => { :target => 'hss-validate' },
      :hss_prod     => { :target => 'hss-prod' },
    },
  },

}[Rails.env.to_sym])
