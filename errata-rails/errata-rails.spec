%global et_install_dir  /var/www/errata_rails

%{?scl:%scl_package errata-rails}
%{!?scl:%global pkg_name %{name}}

Name:           errata-rails
Version:        3.14.4
Release:        0%{?dist}
Summary:        Errata Tool
License: GPL
Group: QA
URL: https://docs.engineering.redhat.com/display/HTD/Errata+Tool
Source0: %{name}-%{version}.tar.gz
BuildRoot:      %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
ExclusiveArch: x86_64
Obsoletes: %{name} < %{version}-%{release}
BuildRequires: libcurl-devel
BuildRequires: mysql-devel
BuildRequires: qpid-cpp-client-devel = 0.34
BuildRequires: qpid-proton-c-devel = 0.10
BuildRequires: rh-ruby22-ruby-devel
BuildRequires: rh-ruby22-rubygem(bundler)
BuildRequires: rh-ruby22-rubygems-devel
BuildRequires: scl-utils
BuildRequires: scl-utils-build
Requires: brewkoji
Requires: cyrus-sasl-gssapi
Requires: finger
Requires: hunspell-en
Requires: krb5-workstation
Requires: mysql-libs
Requires: qpid-cpp-client
Requires: qpid-proton-c
Requires: rh-passenger40
Requires: rh-ruby22-ruby
Requires: rh-ruby22-rubygem(bundler)
Requires: scl-utils
Requires(pre): shadow-utils
Requires(post): chkconfig
%{?scl:Requires: %scl_runtime}

%description
Errata Tool (Ruby on Rails Application)

%prep
%setup -q

%pre
getent group errata >/dev/null || groupadd -r errata
getent passwd erratatool >/dev/null || {
    mkdir -p /usr/local/home &&
    useradd -r -g errata -m -d /usr/local/home/erratatool -c "Errata System" erratatool
}

%build
# Install all required gems into ./vendor/bundle using the handy bundle commmand
scl enable rh-ruby22 - <<-EOF
    set -xe
    bundle install --binstubs \
     --local --deployment \
     --without test development
EOF

%install
rm -rf %buildroot
scl enable rh-ruby22 - <<-EOF
    set -xe
    make install \
        DESTDIR=%{buildroot} \
        VER_REL=%{version}-%{release} \
        RUBY_PATH=\$(which ruby)
EOF
mkdir -p %{buildroot}%{_root_initddir}
cp %{buildroot}%{et_install_dir}/script/delayed_job_service %{buildroot}%{_root_initddir}/delayed_job
chmod +x %{buildroot}%{_root_initddir}/delayed_job
cp %{buildroot}%{et_install_dir}/script/qpid_service %{buildroot}%{_root_initddir}/qpid_service
chmod +x %{buildroot}%{_root_initddir}/qpid_service
cp %{buildroot}%{et_install_dir}/script/messaging_service %{buildroot}%{_root_initddir}/messaging_service
chmod +x %{buildroot}%{_root_initddir}/messaging_service
mkdir %{buildroot}%{_root_sysconfdir}/errata
%clean
rm -rf %buildroot

%files
%defattr(-, erratatool, errata)
%{et_install_dir}
%config(noreplace) %attr(660,erratatool,errata) %{et_install_dir}/config/initializers/credentials/bugzilla.rb
%config(noreplace) %attr(660,erratatool,errata) %{et_install_dir}/config/initializers/credentials/jira.rb
%config(noreplace) %attr(660,erratatool,errata) %{et_install_dir}/config/initializers/credentials/lightblue.rb
%config(noreplace) %attr(660,erratatool,errata) %{et_install_dir}/config/initializers/credentials/message_bus.rb
%config(noreplace) %attr(660,erratatool,errata) %{et_install_dir}/config/initializers/credentials/pub.rb
%config(noreplace) %attr(660,erratatool,errata) %{et_install_dir}/config/initializers/credentials/qpid.rb
%config(noreplace) %attr(660,erratatool,errata) %{et_install_dir}/config/initializers/credentials/rhn.rb
%config(noreplace) %attr(660,erratatool,errata) %{et_install_dir}/config/initializers/credentials/tps_server.rb
%config(noreplace) %attr(660,erratatool,errata) %{et_install_dir}/config/database.yml
%config(noreplace) %attr(660,erratatool,errata) %{et_install_dir}/config/pdc_cpe_list.yml
%defattr(755, root, root)
%{_root_initddir}/delayed_job
%{_root_initddir}/qpid_service
%{_root_initddir}/messaging_service
%attr(750,erratatool,apache) %{_root_sysconfdir}/errata

%post
/sbin/chkconfig --level 2345 delayed_job on
/sbin/chkconfig --level 2345 qpid_service on
/sbin/chkconfig --level 2345 messaging_service on
/bin/date -u > /var/www/errata_rails/public/installed-timestamp.txt

%changelog
* Wed May 03 2017 Wenjie Guo <wguo@redhat.com> 3.14.3-0
- Bug 1441692 Invalid bug ID in Release Notes for Version 3.14.2
- Bug 1440599 Improve bash config inside ET dev docker container
- Bug 1440589 Review which ET instances send UMB monitoring data to Zabbix stage
- Bug 1438924 New "not in product listings" UX is overly-alarming
- Bug 1436935 Could not stop messenger as undefined method 'stopped'
- Bug 1434290 Update release date doesn't send activity.release_date message to UMB
- Bug 1433843 [Regression]Got Error running task move_pushed_errata for Post push items
- Bug 1433833 Couldn't search out user by user's email address in the user/find user page
- Bug 1433832 [Regression] Error "undefined method `gsub!'" is shown when changing a RHSA to Text Only advisory
- Bug 1433269 It list undefined method `enqueue' for MessageBus::SendMsgJob:Class when adding/removing bug
- Bug 1433185 Migrate our docker stuff from docker-registry.usersys.r.c to new supported registry-console.engineering.r.c
- Bug 1427366 Don't cache comments for non-current state group
- Bug 1426988 [RFE] Provide ET's version string via the API
- Bug 1425708 [TS2.0]Basic code development for cucumber acceptance settings which run against a real deployment
- Bug 1421562 [RFE][MX] Add content type support in push metadata
- Bug 1421545 [RFE][MX] Display details of images used for comparison on Container tab
- Bug 1421543 Message lost when permission issue happen
- Bug 1419425 [RFE] API for getting/setting CDN repos for Docker advisory metadata
- Bug 1416283 Should not allow moving text-only advisory from REL_PREP to PUSH_READY if no repo/channel is added
- Bug 1415962 ET pre-push is triggered incorrectly
- Bug 1414599 [errata-migration] revise bash_utils.sh for pdi
- Bug 1412059 [RFE] Support publishing a message with certain fields redacted
- Bug 1411419 we cannot submit RHEA-2017:26124-01 rpmdiff approval
- Bug 1404931 [RFE] Publish all messages to UMB
- Bug 1404923 [RFE] Define the structure of topics for ET on UMB
- Bug 1404919 [RFE] UMB message format definition on ET side
- Bug 1391948 [RFE] Make ET listen for more generic CAT notification messages.
- Bug 1387091 [Ruby 2.2] lib/push_request.rb:2: warning: class variable access from toplevel
- Bug 1386394 Kerberos auth failure when using Mac (was OVAL contents regeneration stopped working)
- Bug 1383581 Monitor the health of ET's connection to the Unified Message Bus
- Bug 1383563 [ansible] Clean up conflicting actions in cert related roles
- Bug 1376282 Obsoleting old released package data seems buggy
- Bug 1312324 [RFE] Include also UD links in notifications about released errata advisories
- Bug 1297555 [RFE] Reschedule CCAT test, with Jira ticket identifier
- Bug 1274206 Push to RHN/CDN (staging and live) should be disabled for text-only advisory if no channel/repo is added to set and product has text_only_advisories_require_dists checked
- Bug 1170417 Add message bus section to developer guide
- Bug 659234 ET: comments for text-only errata added to Security Response bugs need fixing
- Bug 1401366 RFE: API for fetching the state transition history
- Bug 1358105 Advisories with missing file lists for their multi-product mapped product versions should (probably) be prevented from leaving new_files

* Wed Mar 22 2017 Róman Joost <rjoost@redhat.com> 3.14.2-0
- Bug 1431155 [Regression] New errata have qe group unset
- Bug 1428293 ET: certain notification mails now sent with empty body
- Bug 1421879 Can no longer build the publican docs inside the docker dev container
- Bug 1418319 [RFE][MX] Warn about unshipped rpm-based container advisories rather than block
- Bug 1413223 builds.json API does not list builds that lack product listings
- Bug 1406949 [RFE] Provide API access to advisory comments
- Bug 1390568 Use CDN/portal errata page link rather than RHN link in bug comments and customer notification emails
- Bug 1347082 [RFE] Allow kerberos service principals to have an optional email address for notifications
- Bug 1334838 [RFE] API for addition of RHN channels
- Bug 1232064 ProductListingCache.prepare_cached_listings might need to be multi-product listings aware
- Bug 1196005 [Testing] next_release Release Notes should be built in Jenkins
- Bug 1179378 [RFE] Warn if there is a mismatch between rpms included in product listings and in the brew build attached

* Mon Feb 27 2017 Róman Joost <rjoost@redhat.com> 3.14.1.1-0
- Bug 1421539 StagePushGuard should not block text-only errata

* Tue Feb 14 2017 Róman Joost <rjoost@redhat.com> 3.14.1-0
- Bug 1417780 (Docker) Develoment Environment uses hardcoded UIDs
- Bug 1415897 Restore missing rake jobs tasks
- Bug 1414636 [MX] Container tab sometimes fails to display repository and related advisory info
- Bug 1413452 Fix broken KerbCredentials.refresh
- Bug 1405279 Fix add_old_build rake task
- Bug 1402236 [MXR] Fix lightblue-client failing data_url ends with '/'
- Bug 1401743 Docker development images fails to build
- Bug 1400711 Traceback in product listings if brewhub refuses connection
- Bug 1399017 [docker][MX] Docker RHSAs don't have CPE text
- Bug 1392275 [cleanup] Rename errata-rails-ruby2.spec to errata-rails.spec to match the project name
- Bug 1392251 [RFE] Remove the old live_push scripts
- Bug 1386428 TPS scheduling: Stream and Channel should agree
- Bug 1386089 RFE: Expose quality_responsibility_id via /api/v1/erratum
- Bug 1384715 Provide links on Content tab to the (cached) product listings for each brew build
- Bug 1383269 ET: duplicated package listing on the /errata/show_text/ page
- Bug 1381819 text-only advisory without dist should be allowed for middleware products
- Bug 1378728 Missing released package info with ppc64le
- Bug 1378079 [docker] reporting unknown build needs improvement
- Bug 1373336 'MULTI' shows on every advisory which is no longer useful since it's now set by default
- Bug 1370398 Unexplained "overall_score" variable in 5.2.17.6. GET /advisory/{id}/rpmdiff_runs API call
- Bug 1358578 [cleanup] Remove rhnqa_tps_delay setting and associated code
- Bug 1356281 [RFE] Restrictions to creation of CPE names
- Bug 1354242 Flash message hash should allow multiple messages per key
- Bug 1334530 [RFE] Ability to append/remove options/pre_tasks/post_tasks in push API
- Bug 1333734 [Usability]Note for multi_product_mappings may need to updated
- Bug 1333543 "Tps Runs are now complete" comments are added too many times
- Bug 1333242 [RFE] Display multi-product mappings for disabled sources differently
- Bug 1320808 When QE try to create a cdnrepo, the ET keep loading but does not return response
- Bug 1319543 [Doc] Document valid targets, options, pre_tasks, post_tasks in push API
- Bug 1316787 Bugs are not properly syncing their dependencies when they change in Bugzilla (in some cases)
- Bug 1310907 Inconsistent handling of push_files and push_metadata for stage vs live push in API
- Bug 1246174 Improve MultiProduct Delivery Data Availability
- Bug 1244030 Make "Reload files" reload brew files
- Bug 1237102 [Usability] Add action "Delete" for repos/channels into repos/channels overview tabs
- Bug 1232655 Errata in the Need redraft state are shown without their docs reviewers
- Bug 1195574 [RFE] Add email headers to describe changes to make it easier for filtering
- Bug 1112494 [EPIC] Retire the old push scripts and replace them with a suitable API or web UI

* Fri Jan 13 2017 Simon Baird <sbaird@redhat.com> 3.14.0-0
- Bug 1403622 Apache config change for noauth access to /api/v1/security/cpes.json endpoint
- Bug 1403110 [MXR] Support both legacy and new lightblue certificates that require a key file
- Bug 1400090 refresh signatures is throwing an error: undefined method 'id' for ActiveRecord::Relation
- Bug 1396329 [Regression] The pause icon in in the summary page is shown instead as "..."
- Bug 1395051 Test multi-push for docker advisories
- Bug 1393680 Don't offer Docker repos in "RHN Channels/CDN Repos" for text-only advisories
- Bug 1383936 Cleanup dead code after ruby2 migration is complete
- Bug 1381823 Stop trying to obsolete ABIDiff runs
- Bug 1375448 [RFE] Comments with 'info requested' are not sent to my e-mail
- Bug 1374107 Prevent JIRA syncing from becoming stuck by removing DirtyJiraIssue records when issue not accessible
- Bug 1368894 Jira showing as private in ET (edit and published mode) when it's actually public
- Bug 1366124 The api/v1/cdn_repos API doesn't allow (un)linking of multiple variants in POST/PUT requests
- Bug 1348407 [Usability] Remove the white background of 'eso-tab-content' in advisory summary form and update tabs appearance
- Bug 1344155 [Cleanup] Use jbuilder gem instead of lib/jbuilder
- Bug 1321155 errata tool should warn if a variant push target differs from the product defaults
- Bug 1316581 News Feed menu displays spinner forever if feed is empty
- Bug 1306523 Comments wrt unfinished RHNQA and stage push should only appear when required by the active workflow ruleset
- Bug 1303469 Bug.update_from_rpc method doesn't properly work
- Bug 1285701 ET: do not generate push request on IN_PUSH -> PUSH_READY transition
- Bug 1280399 "Product Security approval rescinded." message is confusing
- Bug 1215713 "Component or bug not available?" popup doesn't mention who to contact
- Bug 1104472 Move plugins out of vendor/plugins as per deprecation warnings
* Wed Nov 30 2016 Simon Baird <sbaird@redhat.com> 3.13.4.1-0
- Bug 1399032 [MX] When fixing CVE names for shipped_live docker advisory, we should include the associated CVEs from the RPM advisories
* Thu Nov 22 2016 Simon Baird <sbaird@redhat.com> 3.13.4-0
- Bug 1398543 [MX] Bad displayed text content for Container page which has several repos and rpm advisory
- Bug 1397215 [MX] User guide content for the new Container tab and related functionality
- Bug 1396471 [RFE][MX] Show Bugs/Hide Bugs button should consider jira issues
- Bug 1396347 [RFE][MX] lack of message for docker builds not contain any rpm-based advisories in Container Content Text window
- Bug 1396047 [RFE][MX] More details is required in Container page for the advisory which has no rpm advisory included
- Bug 1395966 [RFE][MX]error occurred 'the server responded with status: ' on advisory summary page when 'Lightblue::ResourceForbiddenError' happened
- Bug 1394065 [MX] Read-only users should have access to advisory container tab
- Bug 1393618 [RFE][MX] Lightblue query optimization for fetching build container details
- Bug 1384791 [RFE][MX] Ensure CVEs associated with constituent rpm-based advisories are included in the CVE list for the docker image advisory
- Bug 1377706 [docker] Bugs are not closed if CDN push completes before CDN Docker push
- Bug 1371334 [RFE][MX] Prevent shipping docker image advisories before their constituent RPM-based advisories are shipped
- Bug 1369969 [RFE][MX] Generate boilerplate advisory text for docker image advisories based on Lightblue data
- Bug 1369963 [RFE][MX] Docker image advisories should display lists of CVEs and RPM based advisories generated by MetaXOR and fetched from Lightblue
- Bug 1369959 [RFE][MX] Develop robust mechanism for Errata Tool to access MetaXOR data from Lightblue
* Wed Nov 09 2016 Simon Baird <sbaird@redhat.com> 3.13.3-0
- Bug 1389145 [Regression] Unintended change to Oval config "public_url"
- Bug 1386011 Skipping SSL cert verification for non-prod Bugzillas is broken in ruby 2
- Bug 1381773 Incorrect docker config file path in Jenkins slave ansible script
- Bug 1381763 Fix broken ActiveRecord relations  that use :select => "distinct ..."
- Bug 1381602 Send notifications to security-response@ instead of secalert@
- Bug 1381389 [Docker] Rename "CDN Repos for Docker Metadata"
- Bug 1381386 [Docker] Don't offer docker repos in "CDN Repos for Docker Metadata"
- Bug 1375085 The push jobs from multi-push should be tracked by one pub task if they have the same push target and option
- Bug 1374665 [docs] wrong ET documentation: docker-attributes-for-non-rpm-files (not applicable for docker files)
- Bug 1374522 Product and product versions on release page should be clickable
- Bug 1365345 Deployment of docker-04 jenkins slave is broken
- Bug 1365219 Push all or select RHBA/RHEA to Product Security XMLRPC server
- Bug 1361374 ET says "All files signed" for some builds with unsigned RPMs
- Bug 1360361 ET: errata metadata pushed to CDN does not include references
- Bug 1359882 [docker] Released images are not tagged to main tag after releasing
- Bug 1341897 please update the Errata User Guide for Errata account/role request with Errata Access process on Maitai
- Bug 1339194 [RFE] Support CORS requests
- Bug 1333252 [RFE] Default signing key should be 'redhatrelease2' rather than 'master'
- Bug 1325862 Unexpected mail subject "RPMDiff results UN-waived" after approving waivers
- Bug 1324581 [RFE] show package name in <title/> for Packages view
- Bug 1318236 ET: unable to set errata filter for inactive batch via web ui
- Bug 1305500 Remove email notifications on push and Product Security approval requests
- Bug 1300910 Provide links to and info about the (cached) product listings that are applicable for each brew build
- Bug 1294766 API for updating batch always update "is_active" to "false" when user update the "is_active" to invalid ones(empty, null and so on)
- Bug 1292774 [RFE] API for comment posting
- Bug 1278692 Should display all unsatisfied batch conditions meantime when trying to move advisory to PUSH_READY
- Bug 1272789 "Depending active errata with locked filelist" on variant edit page won't expand
- Bug 1245460 'Next run' column doesn't sort properly in /background_jobs
- Bug 1182384 [RFE] Brew Tags in product version should warn if overridden by Release
- Bug 1172518 Show the last updated time for the background jobs which would run periodically
- Bug 1166008 Note should be updated to use 'Bugs or JIRA Issues Fixed' instead of 'Bug or Feature IDs fixed' when adding bugs
- Bug 806882 Displayed comment from Update Bug States has been truncated.
* Thu Oct 27 2016 Simon Baird <sbaird@redhat.com> 3.13.2.5-0
- Bug 1388262 Add heartbeat to qpid connection settings to prevent hanging on message send
* Thu Oct 13 2016 Simon Baird <sbaird@redhat.com> 3.13.2.4-0
- Bug 1330496 [errata-migration] Validate scripts in bin/ directory run properly
* Thu Oct 13 2016 Simon Baird <sbaird@redhat.com> 3.13.2.3-0
- Bug 1384283 Fix exception raised when `get_advisory_list' xmlrpc is called with a single product
* Tue Oct 11 2016 Simon Baird <sbaird@redhat.com> 3.13.2.2-0
- Bug 1383134 [errata-migration] Confirm kerberos auth works okay for Covscan and move-pushed-erratum on PDI
* Thu Oct 06 2016 Simon Baird <sbaird@redhat.com> 3.13.2.1-0
- Bug 1375848 [errata-migration] "log writing failed. can't be called from trap context" in qpid_service.output
* Thu Sep 08 2016 Simon Baird <sbaird@redhat.com> 3.13.2-0
- Bug 1371317 [RFE] Live push request emails should not be sent for end-to-end test advisories
- Bug 1370323 Documentation for GET /api/v1/erratum/{id} contains misleading information
- Bug 1369962 [RFE][MX] Provide API to give details about what builds are included in advisories not yet shipped
- Bug 1369606 Multi-push fails if push contains mixture of RPM, docker errata
- Bug 1369298 ActiveRecord::SerializationTypeMismatch when loading StateMachineRuleSet id 8
- Bug 1368582 Remove authentication restrictions for /api/v1/security/cpes.json endpoint
- Bug 1366436 product_versions_used_by_advisory only based on channels
- Bug 1365219 Push all or select RHBA/RHEA to Product Security XMLRPC server
- Bug 1362720 [docker] Don't allow push to repos with no tags
- Bug 1362360 get_advisory_cdn_metadata provides incorrect version/release on RPMs for some builds
- Bug 1362346 [errata-migration] Ensure log files remain group writeable
- Bug 1362064 [docker] tags mapping is connected to the repo and not support stream
- Bug 1361406 Incorrect security impact links generated by ErrataService#get_advisory_cdn_metadata
- Bug 1359546 Hide "Upload errata files" option for CDN pushes of docker errata
- Bug 1358663 [Usability] Adjust the master.css format in order to meet the css requirement
- Bug 1358659 [Usability] Manual create form style adjustment
- Bug 1350916 Builds with non-rpm files are not properly removed when a newer build is added
- Bug 1349662 Public EAP text only errata URLs with no content
- Bug 1343803 [Usability] Nicer and consistent message if CDN docker stage and live push are disabled
- Bug 1343431 CDN docker will be considered not supported incorrectly if CDN Docker live push is disabled
- Bug 1332218 fixcvenames.cgi does not update /cve/list?format=json and it should
- Bug 1325807 [Usability][Regression] ET: edit page Preview button hides parts of the page
- Bug 1320224 Retry when MySQL 'deadlock' or 'lock wait timeout' errors occur
- Bug 1288902 Delayed::Job enqueue_once regularly fails with deadlocks
- Bug 1278713 [RFE] Add an obvious indicator to let users know the batch has been released
- Bug 1278710 Should not be allowed to edit released batches
- Bug 1278684 Batch drop-down list should sort alphabetically to let user find the specific batch easily
- Bug 1278634 [Usability] Warning/error message should be given if creating a new batch with existing batch name
- Bug 1276387 [Usability] Variant context is lost when adding CDN repositories
- Bug 1259551 Errata current_files updates should be made reliable
- Bug 1250640 [RFE] Allow advisories to be created without any bugs/issues
- Bug 1237304 [RFE] Request RCM Push button to trigger mail to RCM queue for RHSA push
- Bug 1071794 [RFE] No advisory shown when checking a bug which with approved component covered by other advisory
- Bug 1000482 [RFE] Improve Channel Mappings for text-only advisory
- Bug 885962 [errata-migration] Need to get notification emails for exceptions on staging and devel servers
* Mon Aug 08 2016 Simon Baird <sbaird@redhat.com> 3.13.1-0
- Bug 1361369 Brew builds in shipped docker advisories do not get released_errata_id set
- Bug 1360133 'RHN' can be always seen in 'RHN live push request' even if the advisory won't be pushed to RHN
- Bug 1359137 [docker] ET to allow '.' char in docker CDN Repo names
- Bug 1354399 Error undefined method `is_debuginfo?' when clicking shipped docker build on docker package page
- Bug 1354328 Advisories listed in 'Active Errata' and 'Shipped Errata' of docker package page should be unique
- Bug 1346362 The "push to buildroot" button should be clickable by QE only
- Bug 1343298 [RFE] Should log a comment for the add/remove 'CDN Repos for Docker Metadata'
- Bug 1341921 [RFE] Add a new API to get rpmdiff result in Errata side
- Bug 1341388 CDN_docker and CDN_Docker_stage push target setting in variants don't take effect
- Bug 1340675 [RFE] Block Docker advisory state transition when no repo added for 'CDN Repos for Docker Metadata'
- Bug 1334127 [errata-migration] Allow/verify unauthenticated access for plain text files (and other assets)
- Bug 1287937 [RFE] Advisories should default to multi-product enabled if there are applicable multi-product mappings
- Bug 1279905 RHSA inside batch release should send push-live request to release-engineering instead of secalert
- Bug 1275874 It is better to give a warning when trying to inactivate a batch which has advisory assigned
- Bug 1273452 ET: security approval condition not shown in filter summary
- Bug 1222713 /release_engineering/product_listings should use url params so you can share links to specific listings
* Thu Aug 04 2016 Simon Baird <sbaird@redhat.com> 3.13.0.1-0
- Bug 1334127 [errata-migration] Allow/verify unauthenticated access for tps.txt (and other assets)
* Tue Jul 12 2016 Simon Baird <sbaird@redhat.com> 3.13.0-0
- Bug 1353391 [RFE] RPMDiff java byte code check support from Errata side
- Bug 1351028 [RFE] Don't make the user enter a file title for a Docker image
- Bug 1349255 Correct/clarify "contact PM" message in the Bug Eligibility page
- Bug 1344160 Script to update volume for all brew builds on ET stage after prod db snapshot load
- Bug 1342020 [errata-migration][Ruby 2.2] delayed jobs for pushing XML to secalert can't be processed
- Bug 1341518 repos in 'CDN Repos for Docker Metadata' field can be updated in any advisory state
- Bug 1341123 [errata-migration] The docs of advisory can not be shown on the PDI stage env
- Bug 1339997 The repo package tag in cdn docker metadata should be unique and can't be duplicate
- Bug 1339996 ET: access.r.c errata url used where rhn.r.c url is expected
- Bug 1339903 installed-version.txt contains the build time rather than the install time
- Bug 1339452 Successful CDN_Docker_stage and CDN_stage push should be required before moving docker advisory from QE to REL_PREP
- Bug 1338800 [RFE] Allow the end-to-end test to get live IDs from a different sequence
- Bug 1338530 [RFE] For Docker advisories, don't allow non-image file types to be selected when adding builds
- Bug 1334609 Rhn channel should not be displayed under advisory Content page if only docker build is added
- Bug 1334146 Existing docker builds in database are not recognized as docker
- Bug 1329525 Active/shipped advisories should be listed in docker package page
- Bug 1329048 [RFE]Add mechanism to prevent removing package/repo mapping while the mapping is used by push
- Bug 1328632 Passing an integer in idsfixed field causes an exception when creating an advisory using the API
- Bug 1327930 Advisory should go to IN_PUSH status and generate comment if only triggering CDN Docker push
- Bug 1318222 ET: remove component from the "Report an Issue" link
- Bug 1306265 ET: limited alias column size can cause ET to not see all bug aliases
- Bug 1151716 [Usability] "Your assigned" redirect to "My Assigned Advisories" which is confusing
* Fri Jun 10 2016 Simon Baird <sbaird@redhat.com> 3.12.5-0
- Bug 1348383 [Regression] Show "Multiple Product Mappings" title above the table
- Bug 1342505 Advisory stuck in IN_PUSH status after CDN push and CDN Docker push completed
- Bug 1342404 Should remove white space around package name when saving repo-mapping for docker repo
- Bug 1341946 ET passes Upload errata files=true to pub even when unchecked for stage push
- Bug 1340140 Docker CDN mapping documentation is incorrect
- Bug 1339204 Push option 'Upload errata files' should be removed for CDN staging push of docker build advisory
- Bug 1339193 CDN_Docker_staging push failed with 'Must be one of: PUSH_READY, IN_PUSH, SHIPPED_LIVE'
- Bug 1338650 [RFE] add alias in Bug Detail section on bugs/troubleshoot page
- Bug 1337734 CDN Docker "push_files" option is useless
- Bug 1336626 ErrataBrewMapping incorrectly handling docker-related (not docker image) files
- Bug 1336388 RHEL 7 whitelist does not include packages that were Level 1
- Bug 1335474 [Ruby 2.2] Unreadable error is thrown when adding new release but leaving some mandatory fields empty
- Bug 1334654 The style/step-status of push to CDN and CDN Docker should be consistent on summary page
- Bug 1334568 Not mapped repos can be listed in CDN file list metadata on push_errata page
- Bug 1334567 [errata-migration]Adjust KerbCredentials so it works for PDI hosts
- Bug 1333935 Extra substitutions when tagging docker content
- Bug 1333763 incorrect product shown in 'Destination Channel/Cdn Repo' field when creating multi-product mapping
- Bug 1333760 auto-complete for Origin Channel/Cdn Repo for RHN was not correct
- Bug 1333752 Unable to update advisory content when advisory includes JIRA issues
- Bug 1333722 multi_product_mappings page cannot be visited if any related repo/channel was deleted
- Bug 1333352 [Regression] 'No such user: preferences' is shown after clicking 'preferences' on ET home page
- Bug 1332774 [Regression] Broken handling of push_files :default on push jobs when advisory has docker images
- Bug 1331690 Developer was able to attach build into disabled Product Versions
- Bug 1330798 Ensure CDN push works for advisories with docker builds
- Bug 1329570 ET should display updated brew links after updating brew in settings.rb on advisory builds section
- Bug 1329495 [errata-migration] kinit fail and no file /etc/errata/errata.keytab in PDI ruby 2.2/1.8 ET host
- Bug 1329493 [errata-migration] /etc/qpid/qpidc.conf missing "ssl-cert-db=/etc/pki/nssdb" causing delayed_job & qpid_service crash
- Bug 1329074 CDN Docker push should be disallowed if removing package mapping for PUSH_READY advisory
- Bug 1328057 Mapped repo previously is missed in the CDN docker metadata on page /push/push_errata/advisory_ID
- Bug 1327518 Advisory stuck in IN_PUSH status after CDN push and CDN Docker push failed second time
- Bug 1327470 Push to CDN Docker should not be allowed for advisory without docker type added
- Bug 1327032 [RFE]"... only RPMs will be included when the advisory is pushed!" need to update as docker push supported
- Bug 1327007 Handle creating docker repo package mapping for packages that don't exist already in ET
- Bug 1327005 Support stage pushes for Docker images
- Bug 1324244 [RFE] Documentation for ET docker image support
- Bug 1320504 Spelling error in "This test verifies that the upstream source tarbals did not change
- Bug 1319567 Retire revision histories for publican books
- Bug 1310073 'Validation failed' requesting 'Product Security Approval' with a JIRA issue the same as a bug alias
- Bug 1304548 [Usability] Display advisory in external test lists
- Bug 1298449 Comment for batch assignment should be generated when RHEA/RHBA is created and assigned a batch
- Bug 1286790 [RFE] Email sent to secalert@ when non-secalert member FINISHES push of RHSA
- Bug 1282291 [RFE] Provide a tracker for one autowaiving rule to find the related rpmdiff result detail
- Bug 1278668 [RFE] Allow pushing docker images to CDN
- Bug 1260855 [RFE] Provide a way to clone autowaiving rules
- Bug 1076276 Provide UI to create and remove multi-product mappings
* Wed May 18 2016 Sunil Thaha <sthaha@redhat.com> 3.12.4-0
- Bug 1318222 ET: remove component from the "Report an Issue" link
- Bug 1330807 Mention voting on the backlog in the ET release notes
- Bug 1278941 [rcm] [performance] adding released packages is SLOW
- Bug 1167242 [RFE] Provide a way to search autowaiver rules in rpmdiff/list_autowaive_rules
- Bug 1260838 who should be the approver and activater in the autowaiving rule workflow
- Bug 1330421 [Regression] wrong number of arguments (3 for 2) when clicking rule ID based on specific result detail
- Bug 1330806 Return 'Error adding autowaiver' when Dev try to edit and apply secruity/releng related rules
- Bug 1334908 CCAT results missing from errata after 04/25
- Bug 1332409 [performance] Optimise find_by_id_or_name to avoid two db queries
- Bug 1329545 [Ruby 2.2][errata-migration] error occurred on visiting update_cyp page
- Bug 1323764 Advisory is not assigned to a batch when release is changed to one that uses batching
- Bug 1323642 ET: inconsistent use of errata URLs across errata formats
- Bug 1319565 [RFE] Provide an easy way to fetch ET's version string
- Bug 1316182 [RFE] Support non-production brew volumes
- Bug 1312154 Bugzilla sync breaks if access is denied to a dirty bug
- Bug 1311397 ET: unset batch when changing errata product or release
- Bug 1308787 [Regression] When viewing the Covscan tab of an advisory, the window title says "CCAT"
- Bug 1308371 [RFE] Support PST stage for non-production OVAL pushes
- Bug 1280531 [Usability] Make advisory filter buttons and UI more understandable
- Bug 1259230 ET: secalert info request generates no notification
* Thu Apr 21 2016 Sunil Thaha <sthaha@redhat.com> 3.12.3-0
- Bug 1189881 ET: make Fix CVE automatically re-push XML to secalert
- Bug 1189882 ET: make it possible to re-send XML to secalert without doing re-push
- Bug 1304925 Investigate alternative methods of deploying dependencies (eg bundle package)
- Bug 1305977 [RFE] When updating CVEs for live errata, re-push OVAL/XML data to the errata-srt service
- Bug 1309570 Minimum/maximum tag length should be restricted when config docker tag
- Bug 1310589 [Usability] Confirm deletion of a CDN repository package tag
- Bug 1315118 get_advisory_cdn_metadata should provide reboot_suggested under pkglist elements
- Bug 1318218 [RFE] ET: Allow the set of advisories in a batch to be locked
- Bug 1320323 ensure no pre-push of embargoed content
- Bug 1323229 different cdn-stage/cdn-live combinations gives different metadata
- Bug 1323541 [Regression] After cloning an advisory the available releases don't match the product
- Bug 1323693 Set title for page with batch details
- Bug 1325801 [Usability] ET: Release is not set when cloning advisory
- Bug 1325820 [Regression] Advisory filter window can't be displayed fully by default
- Bug 1325840 [Regression] colon and field name are not on the same line on advisory creating/editing page
- Bug 1326300 met error 'undefined method `locked' for #<Class:0x7fef537eae60>' showing on UI
* Tue Mar 22 2016 Simon Baird <sbaird@redhat.com> 3.12.2.1-0
- Bug 1318588 [Regression]ET: edit advisory page layout and textarea issues in 3.12.2
- Bug 1314640 Display links to Jira issues filed by CCAT
* Tue Mar 08 2016 Simon Baird <sbaird@redhat.com> 3.12.2-0
- Bug 1311823 An error should be given if invalid release or batch is used in multi-push api
- Bug 1311806 better to remove "Skip subscribing packages (nochannel)" option on pushing to stage page
- Bug 1311802 pre-push jobs failed since ''State QE invalid'
- Bug 1311394 CDN push fail with 'has not been shipped to rhn live channels yet' if multi-push by /api/v1/push
- Bug 1310552 live_rhn_push.rb --metadata-only pushes also files
- Bug 1310540 Readonly user can not navigate to ad pages by the drop-down menu of the ad on the main page
- Bug 1310536 Existing nochannel push jobs should not prevent real rhn/cdn job push
- Bug 1310535 No "Push history" button for accessing push history if trying no channel pushes only
- Bug 1310497 Error 'pub_options mismatch on submitted jobs' is met when multi push RHSA and non-RHSA
- Bug 1310471 Use better fallback fonts when Droid Sans and OverpassBold web fonts are broken
- Bug 1308918 Do not replan batched advisories which are in REL_PREP
- Bug 1304780 [RFE] fix priorities for pub pushes
- Bug 1304588 Add options and pre/post push tasks to push APIs
- Bug 1304278 [Regression]Can't input CPE text on advisory creation or edition page when Text only RHSA
- Bug 1304108 [Regression] ET: incorrect pre-push embargo warning
- Bug 1300153 [RFE] Use pub multi-advisory push when available
- Bug 1300151 [RFE] API for pushing multiple errata
- Bug 1300142 Update get_push_info for multi-advisory push
- Bug 1299721 Use consistent capitalization for "RPMDiff" in UI and in documentation
- Bug 1299719 Update links to documentation to new location
- Bug 1298490 Creating a docker cdn repo with packages mapping via JSON don't work well
- Bug 1298468 [Usability] Comment for set/unset batch blocker for an advisory should be more readable
- Bug 1298418 Sorting by Batch Name(A-Z) and Batch Name(Z-A) should not get the same advisories sequence
- Bug 1280153 Do not change state to REL_PREP after failed push for all errata
- Bug 1278678 [Usability] Should give a message to tell user how to separate multiple bug id/jira issue
- Bug 1278656 [RFE] Manage docker tags for CDN push
- Bug 1278652 [RFE] Add package mappings for docker CDN repos
- Bug 1278649 [Usability] Mark required fields with '*' when manually creating a new advisory
- Bug 1268903 Errata Tool should avoid updating "unchanged" bug statuses to reduce mid air collisions
- Bug 1263935 [Usability]Improve the manual create advisory form
- Bug 1254395 [RFE][Usability] Access different advisory views directly from advisory lists
- Bug 1125038 [RFE][Usability] Display message of XMLRPC::FaultException in bug activity log
- Bug 1112218 [EPIC] Improve workflow for pushing multiple advisories to CDN
- Bug 1054016 [Usability]ET should mark all required input fields when copy/new an advisory manually
- Bug 1009853 I cannot sort releases z-a
- Bug 988169 [RFE] Need a 'server unavailable for scheduled maintenance' mode for upgrades
- Bug 912868 [RFE] Pre-push Errata Advisories
- Bug 510792 rescheduling an rpmdiff run does not cause it to re-find the baseline nvr
* Wed Feb 17 2016 Simon Baird <sbaird@redhat.com> 3.12.1.2-0
- Bug 1305948 CCAT results are not shown for content pushed to RHN and copied to CDN outside ET
- Bug 1304578 Can't access CCAT from admin index
* Wed Feb 17 2016 Simon Baird <sbaird@redhat.com> 3.12.1.1-0
- Bug 1303779 Adding kernel build fails with "kernel-aarch64... has newer or equal version..."
* Thu Jan 28 2016 Sunil Thaha <sthaha@redhat.com> 3.12.1-0
- Bug 1298451 [Regression]Mysql2 error would be shown on ET home page when login ET as readonly role or no any roles
- Bug 1299673 Store and display CCAT ticket URL when provided
- Bug 1298780 [Usability] Differentiate inactive batches in the Advisory Summary page
- Bug 1298058 Add migration to enable CCAT
- Bug 1298057 Reword CCAT "waiting for tests to begin" and hide for old errata
- Bug 1297654 Wrong solution used if product changed during manual advisory create
- Bug 1297261 Remove extra param in link for the "Browse Release Packages" tab
- Bug 1296021 Incomplete product listings created for split product listings if some of the requests timeout and others succeed
- Bug 1295298 Missing "enable_batching" in the "GET /api/v1/releases/*" part of documents
- Bug 1293195 Auto-assigned batch should only happen when advisory is created
- Bug 1291956 "Readonly Admin" explanation isn't needed in documentation
- Bug 1291118 [Performance] The "job_trackers" page is too slow and should top latest jobs
- Bug 1290680 [Performance] Memory leak in delayed_job
- Bug 1290645 [Usability] Don't show CCAT tab until a build is added to the advisory
- Bug 1290596 Should return 404 not 500 when fetch job tracker with unknown id
- Bug 1290459 Errata waiver rule message has a broken URL
- Bug 1289946 Erratum does not change “Release date” when assigned to a Batch
- Bug 1289944 ET is replanning Erratum from a batch to a batch when the Erratum is updated
- Bug 1289800 [RFE] Use ERROR_CAUSE in content test messages to improve CCAT display
- Bug 1289767 Mysql2::Error: Unknown column 'batches.name' if filter sorts by batch name and does not filter by batch
- Bug 1288069 [RFE] Don't do useless big queries
- Bug 1287399 Errors not highlighted on synopsis field
- Bug 1284697 Display default QE owner for QE group at /package/qe_team/:id_or_name
- Bug 1276600 No response when re-clicking edit on security CPE management page
- Bug 1275574 [RFE]Add comment to advisory for batch operations
- Bug 1275212 [Usability]It is better to display 'Not set yet' if batch has no 'Release Date (planned)'  set
- Bug 1273206 Obsolete passed rpmdiff runs can be used as baseline for new runs
- Bug 1272809 [Performance] Log request timing so we can identify slow requests
- Bug 1271062 Replace errata-request@redhat.com with rpmdiff-requests@redhat.com in the tip for request to activate a rule
- Bug 1267260 [RFE] publish advisory ownership changes on the message bus
- Bug 1213838 [RFE] 'push to buildroot' should be configurable
- Bug 1153499 ET: Cannot add bug using alias where bug has multiple aliases
- Bug 1026619 [DOC]The content about accepted bug status should be accurate for filling an advisory in user guide
- Bug 988634 [RFE] Provide access to set state machine rule set for release via the web UI
* Thu Dec 10 2015 Simon Baird <sbaird@redhat.com> 3.12.0-0
- Bug 1289404 The url about /docs/show/Ad_ID in staging.log should match with server environment
- Bug 1287378 Include reboot_suggested as a keyword in get_advisory_rhn_metadata
- Bug 1286713 Make staging push configurable in ruleset, disable for RHEL7.3 and RHEL6.8 errata
- Bug 1284384 Admin tab on the top menu bar should not be visible for readonly user
- Bug 1284125 Higher priority for the background job that updates tps.txt
- Bug 1283454 Remove the 8000 character limit on the 'Bug ID or JIRA Issue Fixed' field
- Bug 1283244 Bad link in "Text ready for review" mail
- Bug 1282748 [Regression][Performance] performance of get_released_{channel,pulp}_packages degraded in ET 3.11.9
- Bug 1280540 [Usability] Confusing message 'Batch release date in future' when moving from rel_prep to push_ready
- Bug 1280161 Released package additions for AUS/EUS should not also add records for mainline RHEL
- Bug 1280147 Fix message bus handler for brokers requiring heartbeat
- Bug 1279769 Pre push errors: Mysql2::Error: Duplicate entry
- Bug 1278646 [RFE] Support docker CDN repos
- Bug 1278249 Create docker images for use in jenkins to test ruby-2 port
- Bug 1276967 Support property-based routing for new message bus
- Bug 1276050 Meet 500 Response Code when "Couldn't find JobTracker with id=6626", should be 404
- Bug 1275548 ET: update special handling of ppc64le for 7.1-EUS
- Bug 1271462 Get released packages can sometimes report rpms not shipped by a channel or cdn repo
- Bug 1263931 Update the header and footer for publican books (in their new location)
- Bug 1263899 [RFE] Listener to detect and process Content Testing status updates
- Bug 1263897 [RFE] Schema and UI additions to record and display Content Testing results for an advisory
- Bug 1257013 [Performance] Background job page should paginate
- Bug 1235178 [RFE] Batch addition of CDN repositories
- Bug 1232662 Reclicking 'Edit' can't open non-rpm file title text field if title is set in the same page
- Bug 1216253 [RFE] Allow partners to be notified about previously embargoed advisories once embargo date passed
- Bug 1204280 Old packages from irrelevant channels provided for layered products
- Bug 1203683 Old packages from irrelevant channels provided (EAP/javassist)
- Bug 1168459 "Receive email" field should be returned from getting real person user details json
- Bug 1156386 [RFE] Read-only admin access for everyone
- Bug 1085414 Devel owner information not available in json advisory details
* Mon Nov 16 2015 Wangsung Kim <brkim@redhat.com> 3.11.9-0
- Bug 1275952 [RFE] Open new page to show individual test when clicking Information mark in list_autowaive_rules
- Bug 1272375 api filter description for batch would wrongly return all the batches
- Bug 1271473 [Usability] There should be some space between 'Impact' drop-down box and 'Create' button on assisted create advisory page
- Bug 1246079 [RFE][Usability] Ajax autocomplete inputbox for product versions in form for manipulation with Released Packages
- Bug 1237289 [RFE] Email sent to secalert@ when non-secalert member pushes RHSA
- Bug 1203909 [RFE] Push jobs should log more verbosely about skipped post-push tasks
- Bug 1203905 [Regression] RHN stage is shown as not pushed while advisory is IN_PUSH
- Bug 1199229 [RFE] In TPS results, make Host column entries ssh:// links
- Bug 1184468 ET: do not change state to REL_PREP after failed push
- Bug 1170308 ET: Ensure CVE names in the CVE field have corresponding CVE bugs
- Bug 1165096 mail to errata-requests@redhat.com should be a link when editing an advisory
- Bug 1278667 [Regression]Bad tab appearance for 'Current Coverity Scan Test Runs'
- Bug 1266350 Same name batch should not be created
- Bug 1235174 Update HTTP API documentation
- Bug 1219367 Has recorded unwaiving result into errata table after failing to unwaive the waived result
- Bug 1205611 [Usability]The "Browse Released Packages" tab should be still highlighted after selecting "Remove Released Packages" button
* Fri Nov 06 2015 Simon Baird <sbaird@redhat.com> 3.11.8.1-0
- Bug 1277858 [Regression] When assigning QE owner the list cannot find user login
* Fri Oct 23 2015 Rohan McGovern <rmcgover@redhat.com> 3.11.8-0
- Bug 1123912 sorting bugs by priority is in suspicious order
- Bug 1126808 [RFE] Create links from references to Jira issues in ET comments
- Bug 1127027 [RFE] Provide UI to view and manage rpmdiff autowaive rules
- Bug 1139078 [Usability] Add a links to info about syncing bugs when user can't add a bug
- Bug 1153062 RFE: exlude debuginfo from ftp by default should be default behavior
- Bug 1167606 [RFE] JSON format of the Package page
- Bug 1170379 Improve logging to include process info
- Bug 1175995 [RFE] Provide a way to define autowaive rules with regular expression
- Bug 1183875 Find New Builds progress bar shows "Please wait" when re-running a failed job
- Bug 1203944 [RFE] Send notification emails when multi-product flag is set for an advisory
- Bug 1204067 [RFE][Usability] Url was shown as ".../rhn/push_results/job_id" incorrectly for cdn_stage/cdn push_results page
- Bug 1210295 Copy/pasting documentation text from the Details tab inserts line breaks
- Bug 1221863 [Performance] Load modal content via ajax when modals are opened
- Bug 1223492 Some CDN-only RHSAs incorrectly include links to RHN
- Bug 1235513 [Usability] Improve the assisted create advisory form.
- Bug 1243279 Enhancement of subpackage item and rpmdiff test result detail
- Bug 1244603 Can't query individual releases in ASYNC, can't get release of builds attached to ASYNC advisories
- Bug 1244849 Unnecessary CVE consistency check warning vs errors
- Bug 1245920 [RFE] Initial support for advisory batches
- Bug 1247901 [Usability] It is better to display 'Product Version For Released Package' instead of 'Product For Released Package' on get product listing page
- Bug 1247955 [Usability] The position of button 'View Cached Listing'  should be above the message 'The latest product listing from Brew is shown below.'
- Bug 1255262 [Usability]It's difficult for user to read the text when hang over the drop-down menu of Per-page/Format on home page
- Bug 1255361 ET: require docs approval before product security approval can be requested
- Bug 1255724 Show release date on the team overview page
- Bug 1256760 Subpackages moved to/from noarch are omitted from get_released_{pulp,channel}_packages
- Bug 1257177 [Regression][Usability] Too much clicking when doing actions on TPS
- Bug 1257408 [Usability]Use consistent date format for recording add released packages
- Bug 1257416 Make publican books available via the app by including their generated html in the rpm
- Bug 1257765 [RFE] Batch state transition guard
- Bug 1257772 [RFE] Update/set advisory to batch automatically
- Bug 1259086 Released package data for RHEL 7 errata incorrectly includes unshipped ppc64le/aarch64 RPMs
- Bug 1260531 [Usability] Clicking 'TPS server' in the tooltip of invalid tps job should open the tps sever page on a new window automatically
- Bug 1264254 [Usability]Use different sytle for the expired and unexpired embargo date on my assigned advisories page consistent with other pages
- Bug 1264267 [Usability]CVE warning should not be combined to one line if it contains multi-sentence
- Bug 1266026 'Actions > Schedule' in the prompt message should be updated on RHEL-7.2.0 advisory DistQA TPS tab
- Bug 1267288 Text-only errata for cdn only product is not being linked to any product
- Bug 1272791 Simplify released package queries to improve performance
* Fri Oct 16 2015 Rohan McGovern <rmcgover@redhat.com> 3.11.7.2-0
- Bug 1271409 [Regression] Get released package slowness after 3.11.7.1 deploy
* Mon Sep 28 2015 Simon Baird <sbaird@redhat.com> 3.11.7.1-0
- Bug 1263867 [Regression] undefined method `name_nonvr' for nil:NilClass on viewing old errata
- Bug 1256760 Subpackages moved to/from noarch are omitted from get_released_{pulp,channel}_packages
- Bug 1247742 Increase priority of post-push background jobs
- Bug 1203683 Old packages from irrelevant channels provided (EAP/javassist)
* Tue Sep 08 2015 Rohan McGovern <rmcgover@redhat.com> 3.11.7-0
- Bug 1257437 It can only show one released package update if trying to update multiple released packges one time
- Bug 1255220 Weird '2 2'/'3 2' appeared on the behind of 'UTC' on the waive result page
- Bug 1254858 [Usability]It's better to show submit comment one time in advisory comment after approving and rejecting some waivers in a single action
- Bug 1254816 Stopping a POST_PUSH_PROCESSING push job doesn't cancel post-push tasks background job
- Bug 1254540 [Usability]Splitting reject reason and submit comment to two lines is more readable
- Bug 1254530 The log of approving waiver and submit comment of approving waiver should be shown on the waive result page
- Bug 1251531 ET: QE owner is now copied when cloning errata
- Bug 1249987 Searching for package failed due to leading whitespaces in the searchbar
- Bug 1241715 push live defaults API call giving errors on first attempt
- Bug 1238040 Unable to track the person who was adding released packages
- Bug 1203496 [RFE] Show information to help make decisions about multi-product advisories
- Bug 1203107 Push only the required arches and subpackages when pushing content to a mapped channel for multi-product advisories
- Bug 1198996 ET: "Check status now" on push job can result in push job post-push tasks running multiple times
- Bug 1198882 Cleanup patch for "IN_PUSH advisories should not block their dependents"
- Bug 1181035 [Usability]Show channels/repos information in advisory build tab
- Bug 1160238 RpmDiff QE review comments are not logged.
- Bug 1152936 ET: Failing post push task should result to unsuccessful push or generate visible notification
- Bug 1148962 Release creation form allows flags that duplicate implicit ones, prevents approved component updates
- Bug 1148672 UI doesn't refresh after "Add comment" if the comment contains autolinks
- Bug 1121159 TPS Stream should come from variant of the product version
- Bug 1113061 [RFE] Calculate 'reboot suggested' value based on packages and include it meta data
* Tue Aug 25 2015 Simon Baird <sbaird@redhat.com> 3.11.6.1-0
- Bug 1254949 Add a link to information about DistQA TPS for RHEL-7.2
* Thu Aug 20 2015 Simon Baird <sbaird@redhat.com> 3.11.6-0
- Bug 1254489 [Regression] Message 'DistQA TPS not blocking' shown incorrectly
- Bug 1229222 Make tps-rhnqa configurable in ruleset, disable for RHEL7.2 errata
- Bug 1222501 ET: rpmdiff compares Supplementary ppc64le build to non-ppc64le build
- Bug 1155162 make errata.activity.status message for embargoed advisories visible to everybody
- Bug 1011781 [Performance] Limit number of advisories in filter using "Show all" option
- Bug 730132 Limits on get_advisory_list
* Fri Jul 31 2015 Simon Baird <sbaird@redhat.com> 3.11.5-0
- Bug 1245659 Many builds are missing aarch64 and ppc64le files
- Bug 1243607 public/tps.txt is generated in-place so TPS can sometimes fetch an incomplete file
- Bug 1241121 Ensure that RecordNotFound exception on api calls returns 404 instead of 400
- Bug 1240514 No response when clicking "Cancel" on changing docs reviewer pop up window
- Bug 1235186 No way how to find out arch_id via API although it's needed in API calls
- Bug 1234750 QA Owner was still default value even if it was changed creating advisory
- Bug 1231628 [RFE][Usability] Improve form for choosing advisory create method
- Bug 1228481 Creating ASYNC advisory through API not restricted by user role
- Bug 1216904 [RFE] Add button to flush a product listing cache or ignore cache at all!
- Bug 1214525 [RFE][Usability] When adding a build it should accept build ids and URLs
- Bug 1203213 [RFE] Expose 'assigned_to' field to ET API
- Bug 1203029 "Find New Builds" with RHEL-LE-7.1.Z or RHEL-7.1.Z and an invalid build causes error
- Bug 1186088 [RFE] provide an API for listing Releases
- Bug 1183476 [RFE] include the errata closure date in the output of get_advisory_list()
- Bug 1167531 User with readonly-admin role should see Admin link in the top menu bar
- Bug 1143831 [RFE][Usability] Add delayed job links for failed job IDs in job trackers
- Bug 1134312 [RFE]Show the link for the number of repos in product versions page
- Bug 1122889 [Testing] ET can't show non_prod jira links for jira issues
- Bug 1103716 ComposeDB: Errata Tool expects layered product have the same variants as base product
- Bug 1099357 Missing HTTP Header - X-XSS-Protection
- Bug 1099355 Missing HTTP Header - X-Content-Type-Options
- Bug 1099354 Missing HTTP Header - X-Frame-Options (prevent click-jacking)
- Bug 1099326 Missing HTTP Header - Strict-Transport-Security
- Bug 1053533 [RFE] Allow builds without product listings
* Mon Jul 20 2015 Simon Baird <sbaird@redhat.com> 3.11.4.1-0
- Bug 1205253 - live_push.rb can't set issue date
* Mon Jun 29 2015 Hao Chang Yu <hyu@redhat.com> 3.11.4-0
- Bug 1228681 Remove/add bug in edit page should rescind docs approval
- Bug 1227156 RHN channels and CDN repos created in RHEL-LE-7.1.Z and RHELSA-7.1.Z  can't be listed in auto-complete menu when trying attach them
- Bug 1222747 Delete RHN channel will sometimes get SQL error message
- Bug 1220940 ET: duplicated post-push runs
- Bug 1215843 Editing an advisory with approved docs requires docs approval permission
- Bug 1214285 [Usability] Text when adding brew build suggests to add build ID, not NVR
- Bug 1206425 Add released packages doesn't check version of brew build before adding
- Bug 1206112 Allow requesting and approving Product Security approval in QE state
- Bug 1196317 [RFE] Request role for ASYNC errata creation
- Bug 1194276 Avoid to move bugs to QE until the errata is moved to QE
* Thu Jun 11 2015 Simon Baird <sbaird@redhat.com> 3.11.3.1-0
- Bug 1220612 [Performance] Loading brew builds page is too slow when an advisory has many builds
* Tue Jun 02 2015 Simon Baird <sbaird@redhat.com> 3.11.3-0
- Bug 1227147 Failed to refresh signed brew builds due to incorrect brew rpm id used to query brew
- Bug 1226777 "Could not get product listings" response from brew should not block adding other builds
- Bug 1222878 Clicking "Edit Brew Tags" can't open brew tags edit page after update
- Bug 1222452 [RFE] Add warning when errata for RHEL-7.1-Supplementary does not include a ppc64le build
- Bug 1221894 [Usability] 'Release Type' should be used to replace 'Type' on rhn channel page
- Bug 1221141 Origin/Variant(Origin) link was missed on some tables about product version
- Bug 1221036 [Usability] The columns should be left-aligned consistently on product version some tables
- Bug 1221028 [Usability] Field name 'Kind'/'Release' can not reflect its meaning in channel/repo list
- Bug 1221009 Variant inheritance relationship can't be found from admin->product admin->product version
- Bug 1220990 When adding builds don't use cached product listings if the listings are empty
- Bug 1220755 Field "Attach" and its value need note to explain its meaning on channel/repo list page
- Bug 1220737 Typo on product version page
- Bug 1220697 Text "Click 'Attach existing' button" is not correct in the note of creating new repo/channel
- Bug 1220693 Cdn repo/rhn channel can't be recognized in auto-complete drop-down menu
- Bug 1220640 CPE text link should not redirect to /errata/details/<id># on advisory details page
- Bug 1220614 [Performance] Loading an advisory summary page with massive builds can be slow
- Bug 1215929 'Date' sorting in rpmdiff runs and 'Review?' sorting in waiver history don't work well
- Bug 1215866 Clicking tab "By Devel Owner" didn't work on page /package/devel_owner/$devel_owner
- Bug 1215861 [Usability] Background gray was missed on header's top right corner of ET some tables
- Bug 1214557 Pagination buttons have inconsistent appearance
- Bug 1210566 [RFE] Add warning when errata for RHEL-7.1 does not include an aarch64 build
- Bug 1210309 Typo on /security/active page
- Bug 1210229 [Performance] Listing all CPE txt on the "Details" page of advisory cost too much time
- Bug 1210214 Collapse the CPE text list if there are a large mount of CPE text
- Bug 1207931 [Performance] Use rails fragment caching to speed up comment rendering
- Bug 1207866 [RFE] Prepare some reports showing advisory life cycle stats, particularly related to TPS
- Bug 1205606 [Usability] Keep "Component or bug not available" info consistent on create Y-stream advisory
- Bug 1186350 [RFE] add possibility to sort by 'release date'
- Bug 1178571 [RFE] Improve channel/repo link display to make links more obvious
- Bug 1167677 Change default Settings.enable_tps_cdn to true
- Bug 1127792 [Usability] Collapse "Obsolete Builds" section by default
- Bug 1123409 [RFE] add cpe(s) to errata summary page
- Bug 1121465 [Performance] get_released_{channel,pulp}_packages takes too long and causes TPS timeouts
- Bug 1040940 [Usability] The column Edit should be left-aligned in RHEL version administration page
* Tue Apr 14 2015 Simon Baird <sbaird@redhat.com> 3.11.2-0
- Bug 1211200 [Regression] CPE text field not shown when text only option selected after failed preview
- Bug 1209724 Warning about docs approval and moving advisory to from PUSH_READY to REL_PREP was missing
- Bug 1208791 [Regression] TPS are not rescheduled when new build is added
- Bug 1208770 [Regression] undefined method `pub_task_errors' returned when trying to fix CPE
- Bug 1207836 [Regression] ET: Erratum not moved from PUSH_READY to REL_PREP after docs edit
- Bug 1206948 "Component or bug not available?" help modal doesn't work after release or product is changed
- Bug 1205999 the "push log" of "Push Results" page can not be refreshed periodically
- Bug 1205551 [Usability] "Product Security Approval" item should be shown as blocked instead of paused if advisory not in REL_PREP
- Bug 1204954 ET: CDN push job immediately marked as failed
- Bug 1202815 ET: fix synopsis field placement in filter dialog
- Bug 1202608 [RFE] Extract <script> block of *.erb to the according js files
- Bug 1201057 PubWatcher should use a separate delayed job for each push job
- Bug 1200127 CDN-only errata hardcode an RHN URL for text docs output
- Bug 1199850 JIRA sync crashes if JIRA issues have no priority: undefined method `name' for nil:NilClass
- Bug 1189351 Brew RPMs and archives with the same ID conflict with each other in Errata Tool
- Bug 1189338 [RFE] Extract inline js code of *.erb files to corresponding js files
- Bug 1186031 post-push processing stops unexpectedly
- Bug 1176487 [RFE] make sure that each js file(containing business logic) pass the JSHint
- Bug 1173489 ET: Fix CVE Names changes are not propagated to Portal
- Bug 1130063 Doing repush without calling pub ends with traceback
- Bug 1120559 Cross Site Scripting(XSS): /rhel_releases/$releasesID
* Tue Mar 31 2015 Simon Baird <sbaird@redhat.com> 3.11.1.1-0
- Bug 1205513 [Performance] Get released packages is very slow
* Mon Mar 23 2015 Hao Chang Yu <hyu@redhat.com> 3.11.1-0
- Bug 1203568 [Usability]Use consistent name "Pulp Repo Label" in cdn repo edit and view page
- Bug 1202920 [Regression] TPS are not rescheduled when new build is added
- Bug 1200607 'Wrong type' error checking product listings when running rake add_old_build
- Bug 1198447 [RFE] Allow grouping by release date in advisory filters
- Bug 1198316 wrong package name returned in get_advisory_cdn_metadata
- Bug 1195643 Show arguments to used for brew call getProductListings
- Bug 1193631 Disallow '.' in CDN Repo Names
- Bug 1193363 et needs to ensure that channel is linked to a new variant after edit it
- Bug 1186021 [RFE] Include synopsis in messages
* Mon Mar 09 2015 Rohan McGovern <rmcgover@redhat.com> 3.11.0-0
- Bug 1197645 [Regression]Sequence of comments are not correct when only push post tasks
- Bug 1191784 [Testing] DocsApprovalRescindTest autotest is unstable
- Bug 1190976 Push to RHN Live  should be shown as green-pass format on advisory summary page after completing rhn live push
- Bug 1190554 Increase delayed job timeout
- Bug 1189445 Error occurred when disable a channel on product version channel list page
- Bug 1189207 DetailedArgumentError (in add_builds) is undefined
- Bug 1189191 Diff are done agains NEW_PACKAGE instead of previous package
- Bug 1188956 [Regression] product_versions JSON view is broken: undefined method `product_version_id'
- Bug 1188563 [Regression]Error "undefined method `empty?' for nil:NilClass" returned on push a text only advisory
- Bug 1188454 [RFE] Support security_approved flag in filters
- Bug 1188183 All push items are shown as not supported for an advisory with only non-rpms added
- Bug 1188141 Rhn live push which is not allowed shown as green-pass incorrectly on advisory summary page after cdn push completed
- Bug 1188115 All push items shown as non-supported incorrectly in advisory summary page after package restriction set for parts of allowable push target
- Bug 1184693 [RFE] Decouple embed js from ruby code in views
- Bug 1184339 The location of Change Qa Owner/Group pop-up window should be in the middle of page
- Bug 1183905 The location of button "Done" is not correct on brew tag editing pop-up window when the number of brew tags is big
- Bug 1183889 Readable error message should be returned after fetching builds repeatedly failed
- Bug 1181388 [Performance] Change Piwik tracking to asynchronous code
- Bug 1180388 OVAL pushes should be disabled by default in non-production environments
- Bug 1180013 move-pushed-erratum sometimes fails with kerberos issues
- Bug 1179973 [Testing] ET documentation should be built in Jenkins
- Bug 1179768 Refactor the eso-theme.js
- Bug 1179602 [RFE]File a ticket to SRT team when an RHSA is transferred to push ready
- Bug 1179522 Find New Builds progress bar remains animated after fetching builds has failed
- Bug 1178132 [RFE] Would be nice to be able to sort items such as the Status or Person on the rpmdiff page
- Bug 1176489 [RFE] Unify the combination manner of IIFE + $(document).ready()
- Bug 1176486 [RFE] Modification according to javascript & jquery best practices
- Bug 1176482 [RFE] Breaking down eso-theme.js
- Bug 1176480 [RFE] Reorganizing the js files in public/javscripts folder
- Bug 1171572 Mysql error in 'escape' triggered by a delayed job
- Bug 1169223 Missing get_released_{channel|pulp}_package for z-stream advisory
- Bug 1168893 do not reshedule all TPS jobs when a particular product version is not updated
- Bug 1168114 [Cleanup] Delete tps stable_systems page from errata
- Bug 1167631 [RFE] Product Security Approval
- Bug 1165696 [RFE] Add checksums to get_advisory_cdn/rhn_file_list
- Bug 1159249 The previously added build type is remove incorrectly when adding another type for the same build again
- Bug 1157890 [Cleanup]  Use Setting.errata_help_email consistently
- Bug 1147209 ET should list non-rpms information in push errata details section
- Bug 1142643 Integrate improved HTTP API documentation in developer guide
- Bug 1139367 [RFE] Need an API for syncing bugs
- Bug 1138332 [RFE] xmlrpc methods for listing non-rpm content
- Bug 1135967 Webui needs optimizing if advisory related packages are disallowed to push to certain target
- Bug 1127337 Re-pushing CDN with no options does repo regeneration
- Bug 1125465 [Testing] Improve uncovered code check to handle a patch series
- Bug 1123417 RFE: expose full product list with cpes via json-api
- Bug 1102976 [cleanup] Investigate, remove product_version duplication in model
- Bug 1102832 Cancelling a push job leaves advisory stuck in IN_PUSH state
- Bug 1101806 If rpmdiff scheduling fails ET thinks advisory has passed rpmdiff since there are no blocking rpmdiff runs
- Bug 1101067 [cleanup] bugs/for_errata.xml.builder view seems to be dead code
- Bug 1099325 Missing Cookie Attributes - Secure
- Bug 1040846 ET: search for errata in IN PUSH state does not work
- Bug 1003652 [RFE] Explicit guidance for y-stream and other types of advisories
- Bug 990361 Delayed Job reopens all the log files and points them to its own log file which cause incorrect log file rotation
