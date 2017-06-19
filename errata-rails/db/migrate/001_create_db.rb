class CreateDb < ActiveRecord::Migration
  def self.up

    create_table "brew_builds",
    :description => 'Contains Brew Build information, obtained via XMLRPC to Brew. NVR info same as in brew build and RPM standards.' do |t|
      t.column "package_id",          :integer,                               :null => false,
      :description => 'Foreign key to errata_packages(id). References package info for the build'
      t.column "epoch",               :string, :limit => nil,
      :description => 'Optional build Epoch'
      t.column "sig_key_id",          :integer,                :default => 5, :null => false,
      :description => 'Foreign key to sig_keys(id). References which GPG key, if any, used to sign the build'
      t.column "signed_rpms_written", :integer,                :default => 0, :null => false,
      :description => 'True if signed rpms have been written to /mnt/brewroot by Brew'
      t.column "version",             :string,  :limit => 50,                 :null => false,
      :description => 'Version part of the build NVR string'
      t.column "release",             :string,  :limit => 50,                 :null => false,
      :description => 'Release part of the build NVR string'
      t.column "nvr",                 :string,                                :null => false,
      :description => "NVR for build. Combination of name, version and release fields for easy lookup"
      t.column "released_errata_id",  :integer,
      :description => "ID of released errata, if any. References errata_main."
    end
    add_index "brew_builds", ["nvr"], :name => "brew_build_nvr"

    create_table "brew_rpms",
    :description => 'Contains information on individual RPMS in a Brew Build,obtained via XMLRPC to Brew. NVR info same as in brew build and RPM standards.' do |t|
      t.column "brew_build_id",   :integer,                               :null => false,
      :description => 'Foreign key to brew_builds(id). RPM Belongs to this build'
      t.column "package_id",      :integer,                               :null => false,
      :description => 'Foreign key to errata_packages(id). References package info for the build'
      t.column "arch_id",         :integer,                               :null => false,
      :description => 'Foreign key to errata_arches(id). References arch info for the build, i.e. i386, ppc64, SRPM'
      t.column "has_cached_sigs", :integer,                :default => 0, :null => false,
      :description => 'True if cached signatures have been created for this RPM by the signing system. DEPRECATED'
      t.column "is_signed",       :integer,                :default => 0, :null => false,
      :description => 'True if signed and written to filesystem by Brew.'
      t.column "name",            :string,
      :description => 'Full NVR of the RPM, i.e. ruby-devel-1.8.6.36-3.fc7'
      t.column "has_brew_sigs",   :integer,                :default => 0, :null => false,
      :description => 'True if signatures have been imported into Brew.'
    end

    create_table "brew_tags",
    :description => 'List of valid brew tags. Associates with releases and product versions.' do |t|
      t.column "name",       :string,   :null => false,
      :description => 'Name of the tag'
      t.column "created_at", :datetime, :null => false,
      :description => 'Creation timestamp'
    end

    add_index "brew_tags", ["name"], :name => "brew_tags_name_key", :unique => true

    create_table "brew_tags_product_versions",
    :description => "Map between brew_tags and product_versions." do |t|
      t.column "product_version_id", :integer, :null => false
      t.column "brew_tag_id",        :integer, :null => false
    end

    create_table "brew_tags_releases",
    :description => "Map between brew_tags and errata_groups" do |t|
      t.column "release_id",  :integer, :null => false
      t.column "brew_tag_id", :integer, :null => false
    end

    create_table "bugs",
    :description => 'Limited copy of information from the buzilla database, obtained by XMLRPC to bugzilla.' do |t|
      t.column "bug_status", :string,                  :null => false,
      :description => 'Status of the bug (NEW, ON_QA, etc)'
      t.column "short_desc", :string,  :limit => 4000, :null => false,
      :description => 'Short description of the bug'
      t.column "package_id", :integer,                 :null => false,
      :description => 'Foreign key to errata_packages(id). References package info for the build'
      t.column "is_private", :integer,                 :null => false,
      :description => 'True if this bug is private'
      t.column "updated_at",  :datetime, :null => false,
      :description => 'Update timestamp'
      t.column "is_security", :integer, :default => 0, :null => false,
      :description => 'True if this bug is in the security produuct'
      t.column "alias", :string,
      :description => 'Alias name for bug'
    end

    create_table "carbon_copies",
    :description => 'List of CC e-mails for an erratum. References errata_main and users.' do |t|
      t.column "errata_id", :integer, :null => false,
      :description => 'Id of errata; references errata_main'
      t.column "who",       :integer, :null => false,
      :description => 'Id of user. References users.'
    end

    create_table "comments",
    :description => 'List of all comments added to an erratum.' do |t|
      t.column "errata_id",       :integer,                                 :null => false,
      :description => 'Foreign key to errata_main(id)'
      t.column "who",        :integer,  :null => false,
      :description => 'Foreign key to users(id). Person who made the comment.'
      t.column "created_at", :datetime, :null => false,
      :description => 'Timestamp when the comment was created'
      t.column "text",       :text,
      :description => 'Text of the comment'
    end
    add_index "comments", ["errata_id"], :name => "comments_errata_idx"

    create_table "errata_activities",
    :description => 'Log of activities that occur during an erratum lifecycle: state changes, file changes, ownership reassignments' do |t|
      t.column "errata_id",     :integer,
      :description => 'References errata_main'
      t.column "who",           :integer,                  :null => false,
      :description => 'Foreign key to users(id). References whom committed the activity'
      t.column "created_at", :datetime,                 :null => false,
      :description => 'When did the activity occur?'
      t.column "what",          :string,                   :null => false,
      :description => 'What was the activity, ex. status, respin, assigned_to'
      t.column "removed",       :string,
      :description => 'The prior state of the what, if applicable. i.e state was ON_QA'
      t.column "added",         :string,
      :description => 'The new state of the what. i.e state is now NEED_DEV'
    end

    add_index "errata_activities", ["errata_id", "what"], :name => "errata_activity_type"

    create_table "errata_arches",
    :description => 'List of all applicable arches that RPMS are built for, i.e. i386, ppc, x86_64' do |t|
      t.column "name", :string, :null => false,
      :description => 'Description of the architecture'
    end

    add_index "errata_arches", ["id"], :name => "errata_arches_id_key", :unique => true
    add_index "errata_arches", ["name"], :name => "errata_arches_name_idx", :unique => true

    create_table "errata_brew_mappings",
    :description => 'Mapping table between errata and brew builds that belong to the errata' do |t|
      t.column "errata_id",          :integer,                                :null => false,
      :description => 'Foreign key to errata_main(id)'
      t.column "brew_build_id",      :integer,                                :null => false,
      :description => 'Foreign key to brew_builds(id)'
      t.column "build_tag",          :string,   :limit => nil,  :description => 'Brew build tag which this build was added with, i.e. dist-5E-extras-qu-candidate '
      t.column "product_version_id", :integer,                                :null => false,
      :description => 'Foreign key to product_versions(id). References the product version for this build, i.e. RHEL-5, RHEL-4-Stacks-V1'
      t.column "package_id",         :integer,                                :null => false,
      :description => 'Foreign key to errata_packages(id). References package info for the build'
      t.column "current",            :integer,                 :default => 1, :null => false,
      :description => 'True if this build is currently part of the erratum.'
      t.column "created_at",         :datetime,                               :null => false,
      :description => 'When this mapping was created'
    end

    create_table "errata_bug_map", :id => false,
    :description => 'DEPRECATED' do |t|
      t.column "errata_id", :integer, :null => false,
      :description => 'Foreign key to errata_main(id)'
      t.column "bug_id",    :integer, :null => false,
      :description => 'Foreign key to bugs(id)'
      t.column "created_at", :datetime, :null => false,
      :description => 'Timestamp of when the association was created.'
    end

    add_index "errata_bug_map", ["bug_id", "errata_id"], :name => "errata_bug_map_idx"

    create_table "errata_content",
    :description => 'So-called content of an erratum, mostly what is considered documentation. Somehwat artificial separation of some errata data into a separate table.' do |t|
      t.column "errata_id",       :integer,                                 :null => false,
      :description => 'Foreign key to errata_main(id)'
      t.column "topic",           :text,                :null => false,
      :description => 'Topic of the erratum.'
      t.column "description",     :text,                                    :null => false,
      :description => 'Problem description for the erratum.'
      t.column "solution",        :text,                                    :null => false,
      :description => 'Solution for correcting the problem.'
      t.column "keywords",        :string,   :limit => 4000,                :null => false,
      :description => 'Any keywords for this erratum, used in RHN searches.'
      t.column "obsoletes",       :string,   :limit => 4000,
      :description => 'List of other errata obsoleted by this advisory'
      t.column "cve",             :string,   :limit => 4000,
      :description => 'Space separated list of CVEs for the erratum. Only valid for RHSA'
      t.column "packages",        :text,
      :description => 'List of packages in erratum. DEPRECATED'
      t.column "multilib",        :text,
      :description => 'Multilib info. DEPRECATED'
      t.column "crossref",        :string,   :limit => 4000,
      :description => 'Cross reference to any related errata.'
      t.column "reference",       :string,   :limit => 4000,
      :description => 'References to other information, typically URLs'
      t.column "how_to_test",     :text,
      :description => 'Description by the developer of how to test the errata.'
      t.column "doc_reviewer_id", :integer,                  :default => 0, :null => false,
      :description => 'Foreign key to users(id). The person assigned to review and edit the documentation of the errata.'
      t.column "updated_at",      :datetime,                                :null => false,
      :description => 'Timestamp of when the content was last updated'
      t.column "revision_count",  :integer,                  :default => 1, :null => false,
      :description => 'Current revision number of the content.'
    end

    add_index "errata_content", ["errata_id"], :name => "errata_content_idx", :unique => true

    create_table "errata_files",
    :description => 'Files that are shipped with an erratum. These are brew rpms that map to multiple variants (4AS, 4ES) and arches.' do |t|
      t.column "errata_id",           :integer,                                      :null => false,
      :description => 'Foreign key to errata_main(id).'
      t.column "version_id",          :integer,                                      :null => false,
      :description => 'Foreign key to errata_versions(id).'
      t.column "arch_id",             :integer,                                      :null => false,
      :description => 'Foreign key to errata_arches(id)'
      t.column "devel_file",          :string,   :limit => 4000,                     :null => false,
      :description => 'Path to the rpm on the file system'
      t.column "ftp_file",            :string,   :limit => 4000,                     :null => false,
      :description => 'Path on the FTP server to which the file is uploaded when the advisory is shipped live.'
      t.column "md5sum",              :string,   :limit => 4000,                     :null => false,
      :description => 'md5sum of the file'
      t.column "change_when",         :datetime,                                     :null => false,
      :description => 'Date when the file was added or updated'
      t.column "current",             :integer,                  :default => 1,      :null => false,
      :description => 'True if this file is currently in the erratum.'
      t.column "who",                 :integer,                                      :null => false,
      :description => 'Foreign key to users(id). Refers to who added the file'
      t.column "signed",              :string,                   :default => "none", :null => false,
      :description => 'Name of the signing key used'
      t.column "rhn_channels",        :string,   :limit => 2000,
      :description => 'DEPRECATED'
      t.column "rhn_beta_channels",   :string,   :limit => 2000,
      :description => 'DEPRECATED'
      t.column "collection",          :string,   :limit => 256,
      :description => 'DEPRECATED'
      t.column "released",            :integer,                  :default => 0,      :null => false,
      :description => 'True if the file has been released'
      t.column "rhn_pkgupload",       :date,
      :description => 'Timestamp when package was last uploaded to RHN Live'
      t.column "rhn_shadow_channels", :string,   :limit => 2000,
      :description => 'DEPRECATED'
      t.column "prior",               :integer,                  :default => 0,      :null => false,
      :description => 'True if this is the most recent prior version of a file'
      t.column "epoch",               :string,
      :description => 'Epoch of the file.'
      t.column "package_id",          :integer,                                      :null => false,
      :description => 'Foreign key to errata_packages(id). Package the file belongs to.'
      t.column "brew_rpm_id",         :integer,                  :default => -1,     :null => false,
      :description => 'Foreign key to brew_rpms(id). Brew RPM for the file'
      t.column "brew_build_id",       :integer,
      :description => 'Foreign key to brew_builds(id). Brew Build for the file'
    end

    add_index "errata_files", ["change_when", "errata_id"], :name => "errata_files_change_idx"
    add_index "errata_files", ["current", "errata_id"], :name => "errata_files_current_idx"
    add_index "errata_files", ["arch_id", "version_id", "errata_id", "id"], :name => "errata_files_idx"
    add_index "errata_files", ["package_id", "current", "errata_id"], :name => "errata_package_index"

    create_table "errata_groups",
    :description => 'Release streams for errata. There are 4 main types: QuarterlyUpdates, ZStream, FastTrrack, and Async(ronous) ' do |t|
      t.column "name",               :string,   :limit => 2000,                                :null => false,
      :description => 'Name of the group'
      t.column "description",        :string,   :limit => 4000,
      :description => 'Descriptive name for the group'
      t.column "enabled",            :integer,                  :default => 1,                 :null => false,
      :description => 'Acts more as a permissions check than name implies. If not set, group will only appear for use by those in pusherrata group'
      t.column "isactive",           :integer,                  :default => 1,                 :null => false,
      :description => 'If set, group will appear in listrequest and be available for use in errata creation.'
      t.column "blocker_bugs",       :string,   :limit => 2000,
      :description => 'DEPRECATED'
      t.column "ship_date",          :datetime,
      :description => 'Date when errata in this group may be shipped live'
      t.column "allow_shadow",       :integer,                  :default => 0,                 :null => false,
      :description => 'Allow errata in this group to be pushed to shadow channels in RHN'
      t.column "allow_beta",         :integer,                  :default => 0,                 :null => false,
      :description => 'Allow errata in this group to be pushed to beta channels in RHN'
      t.column "is_fasttrack",       :integer,                  :default => 0,                 :null => false,
      :description => 'True if this is a Fast Track group. Will be completely DEPRECATED when new system is fully live.'
      t.column "blocker_flags",      :string,   :limit => 200,
      :description => 'Comma separated list of blocker flags in bugzilla. Any bugs added to errata in this group must satisfy these blocker flags'
      t.column "product_version_id", :integer,
      :description => 'Foreign key to product_versions. If set, this default Product Version will be used for errata in this group.'
      t.column "is_async",           :integer,                  :default => 0,                 :null => false,
      :description => 'True if this advisory is asyncronous. Partially DEPRECATED by new type field.'
      t.column "default_brew_tag",   :string,   :limit => nil,
      :description => 'Default brew tag to use when looking up builds for this errata'
      t.column "type",               :string,   :limit => nil,  :default => "QuarterlyUpdate", :null => false,
      :description => 'Inheritance type for groups'
      t.column "allow_blocker",      :integer, :default => 0, :null => false,
      :description => 'If set to 1, allow just the blocker flag presence to allow bug acceptance'
      t.column "allow_exception",    :integer, :default => 0, :null => false,
      :description => 'If set to 1, allow just the exception flag presence to allow bug acceptance'
      t.column "is_deferred",        :integer, :default => 0, :null => false,
      :description => 'If set to 1, any errata created in this group will have a fake id > 8000. e.g. 2009:8019'
    end

    create_table "errata_main",
    :description => 'Main table for errata. Describes most of the data in an errata, and manages much of the relationships to other objects.' do |t|
      t.column "errata_id",          :integer,                                         :null => false,
      :description => 'Numeric part of the fulladvisory. The 0920 in RHSA-2007:0920-02.'
      t.column "revision",           :integer,                  :default => 1,
      :description => 'Revision number for the erratum. The -02 in RHSA-2007:0920-02'
      t.column "errata_type",        :string,   :limit => 64,                          :null => false,
      :description => 'Type of the erratum. One of RHSA|RHBA|RHEA, used as inheritance column.'
      t.column "fulladvisory",       :string,                                          :null => false,
      :description => 'Full advisory string name. In the form of RHSA-2007:0920-02.'
      t.column "issue_date",         :datetime,                                        :null => false,
      :description => 'Date the erratum was created, also updated when it shipps live'
      t.column "update_date",        :datetime,
      :description => 'Date the advisory was last updated.'
      t.column "release_date",       :datetime,
      :description => 'Date erratum released to RHN Live'
      t.column "synopsis",           :string,   :limit => 2000,                        :null => false,
      :description => 'Short description of the erratum'
      t.column "mailed",             :integer,                  :default => 0,
      :description => 'True if the erratum text has been e-mailed to RHN subscribers'
      t.column "pushed",             :integer,                  :default => 0,
      :description => 'True if the erratum has been pushed live'
      t.column "published",          :integer,                  :default => 0,
      :description => '?'
      t.column "deleted",            :integer,                  :default => 0,
      :description => 'True if the erratum is no longer valid. May be DEPRECATED, overlaps DROPPED_NO_SHIP state and valid field'
      t.column "qa_complete",        :integer,                  :default => 0,
      :description => 'True when QA Testing is done'
      t.column "status",             :string,   :limit => 64,   :default => "UNFILED",
      :description => 'State of the erratum. NEW, ON_QA, etc.'
      t.column "resolution",         :string,   :limit => 64,   :default => "",
      :description => 'REsolution of the erratum. COMPLETE|DEFERRED|DROPPED, somewhat DEPRECATED'
      t.column "reporter",           :integer,                                         :null => false,
      :description => 'Foreign key to users(id). Person who filed the advisory.'
      t.column "assigned_to",        :integer,                                         :null => false,
      :description => 'Foreign key to users(id). Quality Engineer to whom testing is assigned.'
      t.column "old_delete_product", :string,
      :description => 'DEPRECATED'
      t.column "severity",           :string,   :limit => 64,   :default => "normal",  :null => false,
      :description => 'Deprecated name. Now used to indicate development group for erratum.'
      t.column "priority",           :string,   :limit => 64,   :default => "normal",  :null => false,
      :description => 'DEPRECATED'
      t.column "rhn_complete",       :integer,                  :default => 0,
      :description => 'DEPRECATED'
      t.column "request",            :integer,                  :default => 0,
      :description => 'DEPRECATED'
      t.column "doc_complete",       :integer,                  :default => 0,
      :description => 'True when documentation has been edited and approved.'
      t.column "valid",              :integer,                  :default => 1,
      :description => 'True if this is a valid erratum.'
      t.column "rhnqa",              :integer,                  :default => 0,
      :description => 'True when erratum has been pushed into RHN testing environment'
      t.column "closed",             :integer,                  :default => 0,
      :description => 'True when erratum has been completed and is considered closed'
      t.column "contract",           :integer,
      :description => 'DEPRECATED'
      t.column "pushcount",          :integer,                  :default => 0,
      :description => 'Number of times erratum has been pushed to RHN Live'
      t.column "class",              :integer,
      :description => 'DEPRECATED'
      t.column "text_ready",         :integer,                  :default => 0,
      :description => 'True when erratum text is ready for documentation review'
      t.column "pkg_owner",          :integer,
      :description => 'Foreign key to users(id). Developer responsible for packages in erratum.'
      t.column "manager_contact",    :integer,
      :description => 'Foreign key to users(id). Person who manages pkg_owner.'
      t.column "rhnqa_shadow",       :integer,                  :default => 0,
      :description => 'True when erratum has been pushed into shadow channels in RHN testing environment.'
      t.column "published_shadow",   :integer,                  :default => 0,
      :description => 'True when erratum has been pushed into shadow channels in RHN Live environment.'
      t.column "current_tps_run",    :integer,
      :description => 'Foreign key to tpsruns(run_id). References the current TPS Run.'
      t.column "filelist_locked",    :integer,                  :default => 0,         :null => false,
      :description => 'True if the filelist is locked.'
      t.column "filelist_changed",   :integer,                  :default => 0,         :null => false,
      :description => 'True if the filelist has been changed when erratum last was in NEED_RESPIN'
      t.column "sign_requested",     :integer,                  :default => 0,         :null => false,
      :description => 'True when signatures have been requested for the brew builds in this advisory.'
      t.column "security_impact",    :string,   :limit => 64,   :default => "",
      :description => 'Security impact, valid for RHSA errata.'
      t.column "product_id",         :integer,                                         :null => false,
      :description => 'Foreign key to errata_products(id). The product for the erratum.'
      t.column "is_brew",            :integer,                  :default => 1,         :null => false,
      :description => 'True if this erratum uses Brew; true for any erratum filed after September 2006'
      t.column "status_updated_at",  :datetime,                                        :null => false,
      :description => 'Timestamp when status was last updated'
      t.column "group_id",           :integer,
      :description => 'Foreign key to errata_groups(id). The release group the erratum belongs to.'
      t.column "created_at",         :datetime, :null => false,
      :description => 'Creation timestamp'
      t.column "updated_at",         :datetime, :null => false,
      :description => 'Update timestamp'
      t.column "respin_count",       :integer,  :default => 0, :null => false,
      :description => 'Count of the number of times this erratum has respun'
      t.column "old_advisory",       :string,
      :description => 'The old advisory_name if this errata was renamed, e.g. from 2009:8196 to 2008:0121'
    end

    add_index "errata_main", ["id"], :name => "errata_main_id_key", :unique => true
    add_index "errata_main", ["valid", "status"], :name => "errata_main_state_idx"
    add_index "errata_main", ["status", "id"], :name => "errata_main_status_idx"

    create_table "errata_packages",
    :description => 'Valid package names for brew builds used in errata system.' do |t|
      t.column "name",       :string,   :null => false,
      :description => 'Name of the package'
      t.column "created_at", :datetime, :null => false,
      :description => 'Timestamp of when a new package  name added to the system.'
    end

    add_index "errata_packages", ["name"], :name => "package_name_idx"
    add_index "errata_packages", ["name"], :name => "pkg_name_uniq", :unique => true

    create_table "errata_priority", :id => false,
    :description => 'Priority scale for errata. DEPRECATED' do |t|
      t.column "value", :string, :null => false,
      :description => 'Name for priority'
    end

    create_table "errata_products",
    :description => 'Set of products in the errata system, e.g. Red Hat Enterprise Linux' do |t|
      t.column "name",        :string,  :limit => 2000,                :null => false,
      :description => 'Name of the product'
      t.column "description", :string,  :limit => 2000,                :null => false,
      :description => 'Brief description of the product'
      t.column "path",        :string,  :limit => 4000,
      :description => 'DEPRECATED'
      t.column "ftp_path",    :string,  :limit => 4000,
      :description => 'Partial Ftp path for the product, if it does not follow the normal FTP path conventions'
      t.column "build_path",  :string,  :limit => 4000,
      :description => 'DEPRECATED'
      t.column "short_name",  :string,
      :description => 'Abbreviation for the product'
      t.column "isactive",    :integer, :default => 1, :null => false,
      :description => 'If set to 1, the product is active. It will show up in UI queries and errata can be filed for it.'
      t.column "allow_ftp",   :integer,                 :default => 0,
      :description => 'This product can be pushed to the ftp server if set to 1'
      t.column "ftp_subdir",  :string,  :limit => nil,
      :description => 'FTP subdirectory for product. System will default to short name if null'
    end

    add_index "errata_products", ["id"], :name => "errata_products_id_key", :unique => true

    create_table "errata_severity", :id => false,
    :description => 'Currently used for development group display in errata system.' do |t|
      t.column "value", :string, :null => false,
      :description => 'Name of the group'
    end

    create_table "errata_types",
    :description => 'List of valid errata types and their description' do |t|
      t.column "name",        :string, :limit => 20,
      :description => 'Name of the type (RHSA, RHEA, etc.)'
      t.column "description", :string,
      :description => 'Description of the type'
    end

    create_table "errata_versions",
    :description => 'List of product variants, i.e. 4AS, 5Server-Stacks' do |t|
      t.column "product_id",         :integer,                 :null => false,
      :description => 'Product ffor this variant. References errata_products'
      t.column "name",               :string,                  :null => false,
      :description => 'Name of the variant'
      t.column "description",        :string,  :limit => 2000,
      :description => 'Description'
      t.column "rhn_channel_tmpl",   :string,  :limit => 2000,
      :description => 'DEPRECATED'
      t.column "product_version_id", :integer,                 :null => false,
      :description => 'Product Version of variant. References product_versions'
      t.column "rhel_variant_id",    :integer,
      :description => 'RHEL Variant for this variant. I.e. 5Server-Stacks would reference 5Server.'
      t.column "rhel_release_id",    :integer,                 :null => false,
      :description => 'RHEL Release version, i.e. RHEL-4. References rhel_releases'
      t.column "cpe",                :string,  :limit => nil,
      :description => 'Common Platform Enumeration of variant. http://cpe.mitre.org/'
    end

    add_index "errata_versions", ["id"], :name => "errata_versions_id_key", :unique => true
    add_index "errata_versions", ["name"], :name => "version_name_uniq", :unique => true

    create_table "product_versions",
    :description => 'Versions of a particular product. I.e. RHEL-4 or RHEL-5 for Red Hat Enterprise Linux' do |t|
      t.column "product_id",       :integer,                :null => false,
      :description => 'Product for this version, references errata_products'
      t.column "name",             :string,  :limit => nil, :null => false,
      :description => 'Name of the product version'
      t.column "description",      :string,  :limit => nil,
      :description => 'Description of this version'
      t.column "default_brew_tag", :string,  :limit => nil,
      :description => 'Default brew tag to use when searching for builds for errata'
      t.column "rhel_release_id",  :integer,
      :description => 'RHEL Release version, i.e. RHEL-4. References rhel_releases'
      t.column "sig_key_id",       :integer,                :null => false,
      :description => 'Signature key to be used for all builds in errata for this product version. References sig_keys'
    end

    add_index "product_versions", ["name"], :name => "errata_product_versions_name_key", :unique => true

    create_table "released_packages",
    :description => 'Set of RPMs released to RHN for an errata. Defines the most recent released build for a product, i.e. most recent RHEL-5 firefox.' do |t|
      t.column "version_id",         :integer,                                :null => false,
      :description => 'Variant of the package. References errata_versions.'
      t.column "package_id",         :integer,                                :null => false,
      :description => 'References errata_packages'
      t.column "arch_id",            :integer,                                :null => false,
      :description => 'Arch released to. Note not neccessarily the same as rpm arch for multi-lib'
      t.column "full_path",          :string,   :limit => nil,                :null => false,
      :description => 'Full path in the filesystem to the brew build and rpms'
      t.column "product_version_id", :integer,                                :null => false,
      :description => 'Product version of this release. References product_versions'
      t.column "current",            :integer,                 :default => 1,
      :description => 'If set to 1, this is the current released package for a particular product version'
      t.column "updated_at",         :datetime,
      :description => 'Timestamp when record updated'
      t.column "rpm_name",           :string,   :limit => nil,
      :description => 'DEPRECATED'
      t.column "brew_rpm_id",        :integer,
      :description => 'Brew RPM released. References brew_rpms'
      t.column "brew_build_id",      :integer,
      :description => 'Brew build released. References brew_builds'
      t.column "created_at",         :datetime,
      :description => 'Timestamp of record creation and when package was released.'
      t.column "errata_id",          :integer,
      :description => 'Errata this package was released in. References errata_main'
    end

    add_index "released_packages", ["arch_id", "package_id", "version_id"], :name => "released_package_version_idx"
    add_index "released_packages", ["product_version_id", "current"], :name => "released_package_pv_index"
    add_index "released_packages", ["errata_id"], :name => "errata_released_package_idx"

    create_table "rhel_releases",
    :description => 'Set of Red Hat Enterprise Linux releases, i.e. 3,4,5' do |t|
      t.column "name",        :string, :limit => nil, :null => false,
      :description => 'Name of release'
      t.column "description", :string, :limit => nil,
      :description => 'Description'
    end

    create_table "rhn_channels",
    :description => 'Set of RHN Channels that errata get pushed to' do |t|
      t.column "version_id",           :integer,                                 :null => false,
      :description => 'Variant for channel. References errata_versions'
      t.column "arch_id",              :integer,                                 :null => false,
      :description => 'Arch for channel. References errata_arches'
      t.column "product_version_id",   :integer,                                 :null => false,
      :description => 'Product version of the channel. References product_versions'
      t.column "created_at",           :datetime,                                :null => false,
      :description => 'Creation timestamp'
      t.column "updated_at",           :datetime,                                :null => false,
      :description => 'Update timestamp'
      t.column "isdefault",            :integer,                  :default => 1, :null => false,
      :description => 'Essentially an is active field'
      t.column "rhn_channel",          :string,   :limit => 2000,                :null => false,
      :description => 'Primary RHN Channel'
      t.column "rhn_beta_channel",     :string,   :limit => 2000,
      :description => 'Beta channel variant'
      t.column "rhn_shadow_channel",   :string,   :limit => 2000,
      :description => 'Shadow version of RHN Channel. Only applies to RHEL'
      t.column "rhn_fastrack_channel", :string,   :limit => 2000,
      :description => 'Fast track version of the channel'
      t.column "rhn_eus_channel",      :string,   :limit => 2000,
      :description => 'EUS channel to be pushed concurrently to.'
    end

    create_table "rhn_push_jobs",
    :description => 'List of all RHN pushes that have occurred. RHN Push is async, so these records are updated until the process terminates.' do |t|
      t.column "errata_id",  :integer,                                       :null => false,
      :description => 'Errata being pushed. References errata_main'
      t.column "pushed_by",  :integer,                                       :null => false,
      :description => 'User pushing the advisory'
      t.column "push_type",  :string,   :limit => 10,                        :null => false,
      :description => 'Type of push. stage or live'
      t.column "status",     :string,                 :default => "STARTED", :null => false,
      :description => 'Status of the push. STARTED, FAILED, COMPLETE'
      t.column "created_at", :datetime,                                      :null => false,
      :description => 'Creation timestamp'
      t.column "updated_at", :datetime,                                      :null => false,
      :description => 'Update timestamp'
      t.column "log",        :text,                   :default => "",        :null => false,
      :description => 'Log from RHN Push process'
    end

    create_table "rpmdiff_results", :primary_key => "result_id",
    :description => 'Results of RPMDiff runs' do |t|
      t.column "run_id",         :integer,                :null => false,
      :description => 'Rpmdiff run for the result. References rpmpdiff_runs'
      t.column "test_id",        :integer,                :null => false,
      :description => 'Test that was run. References rpmdiff_tests'
      t.column "score",          :integer,                :null => false,
      :description => 'Result score'
      t.column "log",            :text,                   :null => true,
      :description => 'Log of rpmdiff run'
      t.column "need_push_priv", :integer, :default => 0, :null => false,
      :description => 'If set to 1, user needs special privileges to waive this result'
    end

    add_index "rpmdiff_results", ["score", "test_id", "run_id", "result_id"], :name => "rpmdiff_results_idx"
    add_index "rpmdiff_results", ["test_id", "run_id"], :name => "rpmdiff_run_test_unique", :unique => true

    create_table "rpmdiff_runs", :primary_key => "run_id",
    :description => 'Set of RPMDiff runs for an erratum' do |t|
      t.column "errata_id",      :integer,                                :null => false,
      :description => 'Erratum run is for. References errata_main'
      t.column "package_name",   :string,   :limit => 240,                :null => false,
      :description => 'Name of package under test'
      t.column "new_version",    :string,   :limit => 240,                :null => false,
      :description => 'NVR of new package'
      t.column "old_version",    :string,   :limit => 240,                :null => false,
      :description => 'NVR of old package'
      t.column "package_path",   :string,   :limit => 400,
      :description => 'Path to the package under test'
      t.column "run_date",       :datetime,                               :null => false,
      :description => 'Date run was executed'
      t.column "overall_score",  :integer,                                :null => false,
      :description => 'Overall score for this run, which encompasses many results'
      t.column "person",         :string,   :limit => 240,                :null => false,
      :description => 'User who scheduled the run'
      t.column "errata_nr",      :string,   :limit => 16,
      :description => 'Short errata id, i.e. 2008:1234'
      t.column "obsolete",       :integer,                 :default => 0, :null => false,
      :description => 'Set to 1 if this is run has been obsoleted by a new one'
      t.column "variant",        :string,   :limit => nil,
      :description => 'RHEL variant name'
      t.column "errata_file_id", :integer,
      :description => 'Reference to the errata file. References errata_files'
    end

    add_index "rpmdiff_runs", ["errata_id"], :name => "rpmdiff_runs_errata_idx"
    add_index "rpmdiff_runs", ["overall_score", "errata_id", "run_id"], :name => "rpmdiff_runs_idx"

    create_table "rpmdiff_scores", 
    :description => 'Set of scores for rpmdiff results' do |t|
      t.column "score", :integer, :null => false,
      :description => 'Numeric id of the score'
      t.column "description", :string,  :limit => 240, :null => false,
      :description => 'Description - Info, Passed, Failed, etc.'
      t.column "html_color",  :string,  :limit => 12,  :null => false,
      :description => 'HTML Color to use in result display'
    end

    create_table "rpmdiff_tests", :primary_key => "test_id",
    :description => 'Set of different rpmdiff tests available.' do |t|
      t.column "description", :string, :limit => 240, :null => false,
      :description => 'Description of the test'
      t.column "long_desc",   :string, :limit => 240, :null => false,
      :description => 'Longer description'
      t.column "wiki_url",    :string, :limit => 240, :null => false,
      :description => 'Link to page further describing test'
    end

    create_table "rpmdiff_waivers", :primary_key => "waiver_id",
    :description => 'Set of waivers for RPMDiff Results' do |t|
      t.column "result_id",   :integer,  :null => false,
      :description => 'Result being waived. References rpmdiff_results'
      t.column "person",      :integer,  :null => false,
      :description => 'Person who waived the result. References users.'
      t.column "description", :text,     :null => false,
      :description => 'Reason for the waiver.'
      t.column "waive_date",  :datetime, :null => false,
      :description => 'Timestamp waiver was created'
      t.column "old_result",  :integer,  :null => false,
      :description => 'Old score of the result'
    end

    add_index "rpmdiff_waivers", ["result_id", "waiver_id"], :name => "rpmdiff_waivers_idx"
    add_index "rpmdiff_waivers", ["old_result", "person"], :name => "rpmdiff_waivers_result_search_idx"

    create_table "sessions",
    :description => 'Sessions table for Rails' do |t|
      t.column "session_id", :string
      t.column "data",       :text
      t.column "updated_at", :datetime
    end

    create_table "sig_keys",
    :description => 'List of valid GPG keys used for signing files' do |t|
      t.column "name",              :string, :limit => nil, :null => false,
      :description => 'Descriptive name of key'
      t.column "keyid",             :string, :limit => nil, :null => false,
      :description => 'Short GPG key id'
      t.column "sigserver_keyname", :string, :limit => nil, :null => false,
      :description => 'Name used for signing server, when used to sign files.'
      t.column "full_keyid",        :string, :limit => nil,
      :description => 'Full GPG id'
    end

    create_table "tps_systems",
    :description => 'Set of valid system types available to run tps jobs. Used in scheduling TPS Runs.' do |t|
      t.column "rhel_release_id", :integer,                               :null => false,
      :description => 'RHEL Release running on system. References rhel_releases'
      t.column "version_id",      :integer,                               :null => false,
      :description => 'Variant of the rhel_release. References errata_versions'
      t.column "arch_id",         :integer,                               :null => false,
      :description => 'Arch of the system. References errata_arches'
      t.column "description",     :string,  :limit => nil,
      :description => 'Short description of system type'
      t.column "enabled",         :integer,                :default => 1, :null => false,
      :description => '1 if system type is available for tps runs'
    end

    create_table "tpsjobs", :primary_key => "job_id",
    :description => 'Set of tps jobs for a tps run across different arches and variants' do |t|
      t.column "run_id",     :integer,                                  :null => false,
      :description => 'TPS Run of job. References tpsruns'
      t.column "arch_id",    :integer,                                  :null => false,
      :description => 'Arch of the job type. References errata_arches'
      t.column "version_id", :integer,                                  :null => false,
      :description => 'RHEL Variant job runs on. References errata_versions'
      t.column "host",       :string,                                   :null => false,
      :description => 'Host the job is run on'
      t.column "state_id",   :integer,                                  :null => false,
      :description => 'Current state of job. References tpsstates'
      t.column "started",    :datetime,                                 :null => false,
      :description => 'Timestamp job started'
      t.column "finished",   :datetime,
      :description => 'Timestamp job finished'
      t.column "link",       :string,                   :default => "", :null => false,
      :description => 'Link to results'
      t.column "link_text",  :string,   :limit => 255, :default => "", :null => false,
      :description => 'Brief description of results'
      t.column "rhnqa",      :integer,                  :default => 0,  :null => false,
      :description => '1 if this is an rhnqa job, 0 otherwise'
    end

    add_index "tpsjobs", ["rhnqa", "version_id", "arch_id"], :name => "tpsjobs_relarch_idx"

    create_table "tpsruns", :primary_key => "run_id",
    :description => 'TPS Run for an erratum' do |t|
      t.column "errata_id", :integer,  :null => false,
      :description => 'Errata job is for. References errata_main'
      t.column "state_id",  :integer,  :null => false,
      :description => 'Current state. References tpsstates'
      t.column "started",   :datetime,
      :description => 'Timestamp job started'
      t.column "finished",  :datetime,
      :description => 'Timestamp job finished.'
      t.column "current", :integer, :null => false, :default => 1,
      :description => 'Set to 1 if this is the current run for the errata'
    end

    create_table "tpsstates",
    :description => 'Set of valid tps states' do |t|
      t.column "state", :string, :null => false,
      :description => 'Name of the state.'
    end

    add_index "tpsstates", ["state", "id"], :name => "tpsstates_state_idx"

    create_table "user_group_map", :id => false,
    :description => 'Map between users and the roles they belong to in the system' do |t|
      t.column "user_id",  :integer, :null => false,
      :description => 'References users'
      t.column "group_id", :integer, :null => false,
      :description => 'References user_groups'
    end

    add_index "user_group_map", ["group_id", "user_id"], :name => "user_group_idx", :unique => true

    create_table "user_organizations",
    :description => 'User organization tree. Mirrors bugzilla org chart.' do |t|
      t.column "name",       :string,
      :description => 'Name of the organization'
      t.column "parent_id",  :integer,
      :description => 'Parent organization'
      t.column "manager_id", :integer,
      :description => 'Manager for the organization. References users'
      t.column "updated_at", :datetime,
      :description => 'Timestamp of org udpdate'
    end

    create_table "user_groups",
    :description => 'List of roles within the errata system, e.g. qa, devel, releng' do |t|
      t.column "name",        :string,
      :description => 'Name of the role'
      t.column "description", :string, :limit => 4000,
      :description => 'Brief description of the role'
    end

    create_table "users",
    :description => 'Set of users in the system' do |t|
      t.column "login_name", :string, :null => false,
      :description => 'e-mail address of user'
      t.column "realname",   :string, :null => false,
      :description => 'Full name of user'
      t.column "user_organization_id", :integer,
      :description => 'Organization user belongs to.'
    end


    add_foreign_key "brew_builds", ["sig_key_id"], "sig_keys", ["id"]
    add_foreign_key "brew_builds", ["released_errata_id"], "errata_main", ["id"]
    add_foreign_key "brew_builds", ["package_id"], "errata_packages", ["id"]

    add_foreign_key "brew_rpms", ["brew_build_id"], "brew_builds", ["id"]
    add_foreign_key "brew_rpms", ["package_id"], "errata_packages", ["id"]
    add_foreign_key "brew_rpms", ["arch_id"], "errata_arches", ["id"]

    add_foreign_key "brew_tags_product_versions", ["product_version_id"], "product_versions", ["id"]
    add_foreign_key "brew_tags_product_versions", ["brew_tag_id"], "brew_tags", ["id"]

    add_foreign_key "brew_tags_releases", ["release_id"], "errata_groups", ["id"]
    add_foreign_key "brew_tags_releases", ["brew_tag_id"], "brew_tags", ["id"]

    add_foreign_key "bugs", ["package_id"], "errata_packages", ["id"]

    add_foreign_key "carbon_copies", ["errata_id"], "errata_main", ["id"]
    add_foreign_key "carbon_copies", ["who"], "users", ["id"]

    add_foreign_key "comments", ["errata_id"], "errata_main", ["id"]
    add_foreign_key "comments", ["who"], "users", ["id"]

    add_foreign_key "errata_activities", ["errata_id"], "errata_main", ["id"]
    add_foreign_key "errata_activities", ["who"], "users", ["id"]

    add_foreign_key "errata_brew_mappings", ["errata_id"], "errata_main", ["id"]
    add_foreign_key "errata_brew_mappings", ["brew_build_id"], "brew_builds", ["id"]
    add_foreign_key "errata_brew_mappings", ["product_version_id"], "product_versions", ["id"]
    add_foreign_key "errata_brew_mappings", ["package_id"], "errata_packages", ["id"]

    add_foreign_key "errata_bug_map", ["errata_id"], "errata_main", ["id"], :name => "errata_bug_fk"
    add_foreign_key "errata_bug_map", ["bug_id"], "bugs", ["id"], :name => "bug_id_fk"

    add_foreign_key "errata_content", ["errata_id"], "errata_main", ["id"], :name => "errata_content_fk"

    add_foreign_key "errata_files", ["errata_id"], "errata_main", ["id"], :name => "errata_files_fk"
    add_foreign_key "errata_files", ["arch_id"], "errata_arches", ["id"], :name => "arch_fk"
    add_foreign_key "errata_files", ["version_id"], "errata_versions", ["id"], :name => "version_fk"
    add_foreign_key "errata_files", ["who"], "users", ["id"], :name => "who_fk"
    add_foreign_key "errata_files", ["brew_build_id"], "brew_builds", ["id"]
    add_foreign_key "errata_files", ["package_id"], "errata_packages", ["id"], :name => "package_fk"

    add_foreign_key "errata_groups", ["product_version_id"], "product_versions", ["id"]

    add_foreign_key "errata_main", ["current_tps_run"], "tpsruns", ["run_id"]
    add_foreign_key "errata_main", ["assigned_to"], "users", ["id"], :name => "assigned_to_fk"
    add_foreign_key "errata_main", ["reporter"], "users", ["id"], :name => "reporter_fk"
    add_foreign_key "errata_main", ["pkg_owner"], "users", ["id"], :name => "pkg_owner_fk"
    add_foreign_key "errata_main", ["manager_contact"], "users", ["id"], :name => "manager_contact_fk"
    add_foreign_key "errata_main", ["product_id"], "errata_products", ["id"], :name => "product_id_fk"
    add_foreign_key "errata_main", ["group_id"], "errata_groups", ["id"]


    add_foreign_key "errata_versions", ["product_id"], "errata_products", ["id"], :name => "product_fk"
    add_foreign_key "errata_versions", ["rhel_release_id"], "rhel_releases", ["id"]
    add_foreign_key "errata_versions", ["rhel_variant_id"], "errata_versions", ["id"]
    add_foreign_key "errata_versions", ["product_version_id"], "product_versions", ["id"]

    add_foreign_key "product_versions", ["sig_key_id"], "sig_keys", ["id"]
    add_foreign_key "product_versions", ["rhel_release_id"], "rhel_releases", ["id"]
    add_foreign_key "product_versions", ["product_id"], "errata_products", ["id"]

    add_foreign_key "released_packages", ["version_id"], "errata_versions", ["id"]
    add_foreign_key "released_packages", ["package_id"], "errata_packages", ["id"]
    add_foreign_key "released_packages", ["arch_id"], "errata_arches", ["id"]
    add_foreign_key "released_packages", ["product_version_id"], "product_versions", ["id"]
    add_foreign_key "released_packages", ["brew_build_id"], "brew_builds", ["id"]
    add_foreign_key "released_packages", ["errata_id"], "errata_main", ["id"]
    add_foreign_key "released_packages", ["brew_rpm_id"], "brew_rpms", ["id"]

    add_foreign_key "rhn_channels", ["version_id"], "errata_versions", ["id"]
    add_foreign_key "rhn_channels", ["arch_id"], "errata_arches", ["id"]
    add_foreign_key "rhn_channels", ["product_version_id"], "product_versions", ["id"]

    add_foreign_key "rhn_push_jobs", ["errata_id"], "errata_main", ["id"]
    add_foreign_key "rhn_push_jobs", ["pushed_by"], "users", ["id"]

    add_foreign_key "rpmdiff_results", ["run_id"], "rpmdiff_runs", ["run_id"]
    add_foreign_key "rpmdiff_results", ["test_id"], "rpmdiff_tests", ["test_id"]
    add_foreign_key "rpmdiff_results", ["score"], "rpmdiff_scores", ["id"], :name => "rpmdiff_result_score_fk"

    add_foreign_key "rpmdiff_runs", ["errata_id"], "errata_main", ["id"], :name => "errata_rpmdiff_run_fk"
    add_foreign_key "rpmdiff_runs", ["overall_score"], "rpmdiff_scores", ["id"], :name => "rpmdiff_run_score_fk"
    add_foreign_key "rpmdiff_runs", ["errata_file_id"], "errata_files", ["id"]

    add_foreign_key "rpmdiff_waivers", ["result_id"], "rpmdiff_results", ["result_id"], :on_delete => :cascade, :name => "waivers_fk_result_id"
    add_foreign_key "rpmdiff_waivers", ["person"], "users", ["id"], :name => "person_fk"

    add_foreign_key "tps_systems", ["rhel_release_id"], "rhel_releases", ["id"]
    add_foreign_key "tps_systems", ["version_id"], "errata_versions", ["id"]
    add_foreign_key "tps_systems", ["arch_id"], "errata_arches", ["id"]

    add_foreign_key "tpsjobs", ["run_id"], "tpsruns", ["run_id"]
    add_foreign_key "tpsjobs", ["arch_id"], "errata_arches", ["id"]
    add_foreign_key "tpsjobs", ["version_id"], "errata_versions", ["id"]
    add_foreign_key "tpsjobs", ["state_id"], "tpsstates", ["id"]

    add_foreign_key "tpsruns", ["errata_id"], "errata_main", ["id"]
    add_foreign_key "tpsruns", ["state_id"], "tpsstates", ["id"]

    add_foreign_key "user_group_map", ["user_id"], "users", ["id"]
    add_foreign_key "user_group_map", ["group_id"], "user_groups", ["id"]

    add_foreign_key "user_organizations", ["parent_id"], "user_organizations", ["id"]
    add_foreign_key "user_organizations", ["manager_id"], "users", ["id"]

    add_foreign_key "users", ["user_organization_id"], "user_organizations", ["id"]

  end

  def self.down

  end
end
