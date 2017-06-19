# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20170601010940) do

  create_table "abidiff_runs", :force => true do |t|
    t.integer "errata_id", :null => false
    t.integer "brew_build_id", :null => false
    t.string "status", :null => false
    t.boolean "current", :default => true, :null => false
    t.datetime "timestamp", :null => false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "result"
    t.string "message"
  end

  create_table "active_push_targets", :force => true do |t|
    t.integer "product_version_id", :null => false
    t.integer "push_target_id", :null => false
    t.integer "who_id", :null => false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "default_solutions", :force => true do |t|
    t.string "title", :null => false
    t.text "text", :null => false
    t.boolean "active", :default => true, :null => false
  end

  create_table "pdc_resources", :force => true do |t|
    t.string "type", :null => false
    t.string "pdc_id", :null => false
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
    t.index ["pdc_id"], :name => "index_pdc_resources_on_pdc_id"
  end

  create_table "errata_products", :force => true do |t|
    t.string "name", :limit => 2000, :null => false
    t.string "description", :limit => 2000, :null => false
    t.string "path", :limit => 4000
    t.string "ftp_path", :limit => 4000
    t.string "build_path", :limit => 4000
    t.string "short_name", :null => false
    t.integer "isactive", :default => 1, :null => false
    t.string "ftp_subdir"
    t.integer "default_solution_id"
    t.string "valid_bug_states", :default => "MODIFIED,VERIFIED"
    t.integer "state_machine_rule_set_id"
    t.string "cdw_flag_prefix"
    t.boolean "is_internal", :default => false, :null => false
    t.boolean "move_bugs_on_qe", :default => false, :null => false
    t.boolean "supports_pdc", :default => false, :null => false
    t.integer "pdc_product_id"
    t.boolean "text_only_advisories_require_dists", :default => true, :null => false
    t.index ["default_solution_id"], :name => "default_solution_id"
    t.index ["id"], :name => "errata_products_id_key", :unique => true
    t.index ["isactive"], :name => "index_errata_products_on_isactive"
    t.index ["pdc_product_id"], :name => "product_pdc_product_id_fk"
    t.index ["short_name"], :name => "index_errata_products_on_short_name", :unique => true
    t.foreign_key ["default_solution_id"], "default_solutions", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "errata_products_ibfk_1"
    t.foreign_key ["pdc_product_id"], "pdc_resources", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "product_pdc_product_id_fk"
  end

  create_table "rhel_releases", :force => true do |t|
    t.string "name", :null => false
    t.string "description", :limit => 4000, :null => false
    t.boolean "exclude_ftp_debuginfo", :default => true, :null => false
  end

  create_table "sig_keys", :force => true do |t|
    t.string "name", :null => false
    t.string "keyid", :null => false
    t.string "sigserver_keyname", :null => false
    t.string "full_keyid"
  end

  create_table "product_versions", :force => true do |t|
    t.integer "product_id", :null => false
    t.string "name", :null => false
    t.string "description"
    t.string "default_brew_tag"
    t.integer "rhel_release_id", :null => false
    t.integer "sig_key_id", :null => false
    t.integer "is_server_only", :default => 0, :null => false
    t.integer "enabled", :default => 1, :null => false
    t.boolean "allow_rhn_debuginfo", :default => false
    t.boolean "forbid_ftp", :default => false
    t.boolean "is_oval_product", :default => false, :null => false
    t.boolean "is_rhel_addon", :default => false, :null => false
    t.boolean "supports_cdn", :default => false, :null => false
    t.integer "base_product_version_id"
    t.string "unused_push_types"
    t.string "permitted_build_flags"
    t.index ["base_product_version_id"], :name => "base_product_version_id"
    t.index ["name"], :name => "errata_product_versions_name_key", :unique => true
    t.index ["product_id"], :name => "product_id"
    t.index ["rhel_release_id"], :name => "rhel_release_id"
    t.index ["sig_key_id"], :name => "sig_key_id"
    t.foreign_key ["base_product_version_id"], "product_versions", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "product_versions_ibfk_4"
    t.foreign_key ["product_id"], "errata_products", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "product_versions_ibfk_3"
    t.foreign_key ["rhel_release_id"], "rhel_releases", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "product_versions_ibfk_2"
    t.foreign_key ["sig_key_id"], "sig_keys", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "product_versions_ibfk_1"
  end

  create_table "user_organizations", :force => true do |t|
    t.string "name", :null => false
    t.integer "parent_id"
    t.integer "manager_id", :null => false
    t.datetime "updated_at", :null => false
    t.integer "orgchart_id"
    t.index ["manager_id"], :name => "manager_id"
    t.index ["parent_id"], :name => "parent_id"
  end

  add_foreign_key "user_organizations", ["parent_id"], "user_organizations", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "user_organizations_ibfk_1"

  create_table "users", :force => true do |t|
    t.string "login_name", :null => false
    t.string "realname", :null => false
    t.integer "user_organization_id", :null => false
    t.integer "enabled", :default => 1, :null => false
    t.boolean "receives_mail", :default => true, :null => false
    t.string "preferences", :default => "--- {}\n\n"
    t.integer "orgchart_id"
    t.string "email_address"
    t.index ["login_name"], :name => "index_users_on_login_name", :unique => true
    t.index ["user_organization_id"], :name => "user_organization_id"
    t.foreign_key ["user_organization_id"], "user_organizations", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "users_ibfk_1"
  end

  add_foreign_key "user_organizations", ["manager_id"], "users", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "user_organizations_ibfk_2"

  create_table "releases", :force => true do |t|
    t.string "name", :limit => 2000, :null => false
    t.string "description", :limit => 4000, :null => false
    t.integer "enabled", :default => 1, :null => false
    t.integer "isactive", :default => 1, :null => false
    t.string "blocker_bugs", :limit => 2000
    t.datetime "ship_date"
    t.integer "allow_shadow", :default => 0, :null => false
    t.integer "allow_beta", :default => 0, :null => false
    t.string "blocker_flags", :limit => 200
    t.integer "product_version_id"
    t.integer "is_async", :default => 0, :null => false
    t.string "default_brew_tag"
    t.string "type", :default => "QuarterlyUpdate", :null => false
    t.integer "allow_blocker", :default => 0, :null => false
    t.integer "allow_exception", :default => 0, :null => false
    t.integer "is_deferred", :default => 0, :null => false
    t.integer "product_id"
    t.string "url_name", :null => false
    t.datetime "bugs_last_synched_at"
    t.integer "program_manager_id"
    t.integer "state_machine_rule_set_id"
    t.boolean "allow_pkg_dupes", :default => false, :null => false
    t.boolean "enable_batching", :default => false, :null => false
    t.boolean "is_pdc", :default => false, :null => false
    t.index ["product_id"], :name => "product_id"
    t.index ["product_version_id"], :name => "product_version_id"
    t.index ["program_manager_id"], :name => "program_manager_id"
    t.foreign_key ["product_id"], "errata_products", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "releases_ibfk_2"
    t.foreign_key ["product_version_id"], "product_versions", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "releases_ibfk_1"
    t.foreign_key ["program_manager_id"], "users", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "releases_ibfk_3"
  end

  create_table "batches", :force => true do |t|
    t.string "name", :null => false
    t.integer "release_id", :null => false
    t.string "description", :limit => 2000
    t.datetime "release_date"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
    t.boolean "is_active", :default => true, :null => false
    t.integer "who_id", :null => false
    t.datetime "released_at"
    t.boolean "is_locked", :default => false, :null => false
    t.index ["release_id"], :name => "batches_releases_ibfk_1"
    t.index ["who_id"], :name => "who_id"
    t.foreign_key ["release_id"], "releases", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "batches_releases_ibfk_1"
    t.foreign_key ["who_id"], "users", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "batches_ibfk_1"
  end

  create_table "errata_responsibilities", :force => true do |t|
    t.string "name", :null => false
    t.string "type", :null => false
    t.integer "default_owner_id", :null => false
    t.integer "user_organization_id", :null => false
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
    t.string "url_name", :null => false
    t.index ["default_owner_id"], :name => "default_owner_id"
    t.index ["type"], :name => "index_errata_responsibilities_on_type"
    t.index ["user_organization_id"], :name => "user_organization_id"
    t.foreign_key ["default_owner_id"], "users", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "errata_responsibilities_ibfk_1"
    t.foreign_key ["user_organization_id"], "user_organizations", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "errata_responsibilities_ibfk_2"
  end

  create_table "state_indices", :force => true do |t|
    t.integer "errata_id", :null => false
    t.string "current", :null => false
    t.string "previous", :null => false
    t.integer "who_id", :null => false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["errata_id"], :name => "index_state_indices_on_errata_id"
  end

  create_table "errata_main", :force => true do |t|
    t.integer "revision", :default => 1
    t.string "errata_type", :limit => 64, :null => false
    t.string "fulladvisory"
    t.datetime "issue_date", :null => false
    t.datetime "update_date"
    t.datetime "release_date"
    t.string "synopsis", :limit => 2000, :null => false
    t.integer "mailed", :default => 0
    t.integer "pushed", :default => 0
    t.integer "published", :default => 0
    t.integer "deleted", :default => 0
    t.integer "qa_complete", :default => 0
    t.string "status", :limit => 64, :default => "NEW_FILES", :null => false
    t.string "resolution", :limit => 64, :default => ""
    t.integer "reporter_id", :null => false
    t.integer "assigned_to_id", :null => false
    t.string "old_delete_product"
    t.string "severity", :limit => 64, :default => "normal", :null => false
    t.string "priority", :limit => 64, :default => "normal", :null => false
    t.integer "rhn_complete", :default => 0
    t.integer "request", :default => 0
    t.integer "doc_complete", :default => 0
    t.integer "rhnqa", :default => 0
    t.integer "closed", :default => 0
    t.integer "contract"
    t.integer "pushcount", :default => 0
    t.integer "text_ready", :default => 0
    t.integer "package_owner_id"
    t.integer "manager_id"
    t.integer "rhnqa_shadow", :default => 0
    t.integer "published_shadow", :default => 0
    t.integer "current_tps_run"
    t.integer "filelist_locked", :default => 0, :null => false
    t.integer "filelist_changed", :default => 0, :null => false
    t.integer "sign_requested", :default => 0, :null => false
    t.string "security_impact", :limit => 64, :default => ""
    t.integer "product_id", :null => false
    t.integer "is_brew", :default => 1, :null => false
    t.datetime "status_updated_at", :null => false
    t.integer "group_id", :null => false
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
    t.integer "respin_count", :default => 0, :null => false
    t.string "old_advisory"
    t.integer "rating", :default => 0, :null => false
    t.integer "docs_responsibility_id", :default => 1, :null => false
    t.integer "quality_responsibility_id", :default => 2, :null => false
    t.integer "devel_responsibility_id", :default => 3, :null => false
    t.integer "is_valid", :default => 1, :null => false
    t.integer "current_state_index_id"
    t.boolean "text_only", :default => false, :null => false
    t.datetime "publish_date_override"
    t.integer "state_machine_rule_set_id"
    t.datetime "actual_ship_date"
    t.boolean "supports_multiple_product_destinations"
    t.boolean "security_approved"
    t.integer "batch_id"
    t.boolean "is_batch_blocker", :default => false, :null => false
    t.integer "request_rcm_push_comment_id"
    t.text "content_types"
    t.index ["assigned_to_id"], :name => "assigned_to_fk"
    t.index ["batch_id"], :name => "batch_id"
    t.index ["current_state_index_id"], :name => "current_state_index_id"
    t.index ["current_tps_run"], :name => "current_tps_run"
    t.index ["devel_responsibility_id"], :name => "devel_responsibility_id"
    t.index ["docs_responsibility_id"], :name => "docs_responsibility_id"
    t.index ["group_id"], :name => "group_id"
    t.index ["id"], :name => "errata_main_id_key", :unique => true
    t.index ["manager_id"], :name => "manager_contact_fk"
    t.index ["package_owner_id"], :name => "pkg_owner_fk"
    t.index ["product_id"], :name => "product_id_fk"
    t.index ["quality_responsibility_id"], :name => "quality_responsibility_id"
    t.index ["reporter_id"], :name => "reporter_fk"
    t.index ["status", "id"], :name => "errata_main_status_idx"
    t.index ["status"], :name => "errata_main_state_idx"
    t.foreign_key ["batch_id"], "batches", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "errata_main_batches_id_fk"
    t.foreign_key ["current_state_index_id"], "state_indices", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "errata_main_ibfk_6"
    t.foreign_key ["devel_responsibility_id"], "errata_responsibilities", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "errata_main_ibfk_5"
    t.foreign_key ["docs_responsibility_id"], "errata_responsibilities", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "errata_main_ibfk_3"
    t.foreign_key ["group_id"], "releases", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "errata_main_ibfk_2"
    t.foreign_key ["product_id"], "errata_products", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "product_id_fk"
    t.foreign_key ["quality_responsibility_id"], "errata_responsibilities", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "errata_main_ibfk_4"
  end

  create_table "advisory_dependencies", :id => false, :force => true do |t|
    t.integer "blocking_errata_id", :null => false
    t.integer "dependent_errata_id", :null => false
    t.index ["blocking_errata_id"], :name => "blocking_errata_id"
    t.index ["dependent_errata_id"], :name => "dependent_errata_id"
    t.foreign_key ["blocking_errata_id"], "errata_main", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "advisory_dependencies_ibfk_1"
    t.foreign_key ["dependent_errata_id"], "errata_main", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "advisory_dependencies_ibfk_2"
  end

  create_table "allowable_push_targets", :force => true do |t|
    t.integer "product_id", :null => false
    t.integer "push_target_id", :null => false
    t.integer "who_id", :null => false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "backup_channels", :force => true do |t|
    t.string "name", :null => false
    t.string "ctype", :null => false
    t.integer "primary_channel_id"
    t.integer "version_id", :null => false
    t.integer "arch_id", :null => false
    t.integer "product_version_id", :null => false
    t.string "cdn_path"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "blocking_issues", :force => true do |t|
    t.integer "errata_id", :null => false
    t.integer "state_index_id", :null => false
    t.integer "user_id", :null => false
    t.integer "blocking_role_id", :null => false
    t.string "summary", :null => false
    t.string "description", :limit => 4000, :null => false
    t.boolean "is_active", :null => false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["errata_id"], :name => "index_blocking_issues_on_errata_id"
  end

  create_table "brew_archive_types", :force => true do |t|
    t.string "extensions", :null => false
    t.string "name", :null => false
    t.text "description"
    t.index ["name"], :name => "index_brew_archive_types_on_name", :unique => true
  end

  create_table "packages", :force => true do |t|
    t.string "name", :null => false
    t.datetime "created_at", :null => false
    t.integer "devel_owner_id", :null => false
    t.integer "qe_owner_id", :null => false
    t.integer "docs_responsibility_id", :default => 1, :null => false
    t.integer "quality_responsibility_id", :default => 2, :null => false
    t.integer "devel_responsibility_id", :default => 3, :null => false
    t.index ["devel_owner_id"], :name => "devel_owner_id"
    t.index ["devel_responsibility_id"], :name => "devel_responsibility_id"
    t.index ["docs_responsibility_id"], :name => "docs_responsibility_id"
    t.index ["name"], :name => "package_name_idx"
    t.index ["name"], :name => "pkg_name_uniq", :unique => true
    t.index ["qe_owner_id"], :name => "qe_owner_id"
    t.index ["quality_responsibility_id"], :name => "quality_responsibility_id"
    t.foreign_key ["devel_owner_id"], "users", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "packages_ibfk_1"
    t.foreign_key ["devel_responsibility_id"], "errata_responsibilities", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "packages_ibfk_5"
    t.foreign_key ["docs_responsibility_id"], "errata_responsibilities", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "packages_ibfk_3"
    t.foreign_key ["qe_owner_id"], "users", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "packages_ibfk_2"
    t.foreign_key ["quality_responsibility_id"], "errata_responsibilities", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "packages_ibfk_4"
  end

  create_table "brew_builds", :force => true do |t|
    t.integer "package_id", :null => false
    t.string "epoch"
    t.integer "sig_key_id", :default => 5, :null => false
    t.integer "signed_rpms_written", :default => 0, :null => false
    t.string "version", :limit => 50, :null => false
    t.string "release", :limit => 50, :null => false
    t.string "nvr", :null => false
    t.integer "released_errata_id"
    t.integer "shipped", :default => 0, :null => false
    t.string "volume_name"
    t.index ["nvr"], :name => "index_brew_builds_on_nvr", :unique => true
    t.index ["package_id"], :name => "package_id"
    t.index ["released_errata_id"], :name => "released_errata_id"
    t.index ["sig_key_id"], :name => "sig_key_id"
    t.foreign_key ["package_id"], "packages", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "brew_builds_ibfk_3"
    t.foreign_key ["released_errata_id"], "errata_main", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "brew_builds_ibfk_2"
    t.foreign_key ["sig_key_id"], "sig_keys", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "brew_builds_ibfk_1"
  end

  create_table "errata_arches", :force => true do |t|
    t.string "name", :null => false
    t.boolean "active", :default => true, :null => false
    t.index ["id"], :name => "errata_arches_id_key", :unique => true
    t.index ["name"], :name => "errata_arches_name_idx", :unique => true
  end

  create_table "brew_files", :force => true do |t|
    t.integer "brew_build_id", :null => false
    t.integer "package_id", :null => false
    t.integer "arch_id"
    t.integer "has_cached_sigs", :default => 0, :null => false
    t.integer "is_signed", :default => 0, :null => false
    t.string "name", :null => false
    t.integer "has_brew_sigs", :default => 0, :null => false
    t.integer "epoch", :default => 0, :null => false
    t.string "type", :default => "BrewRpm", :null => false
    t.integer "brew_archive_type_id"
    t.string "relpath"
    t.string "maven_groupId"
    t.string "maven_artifactId"
    t.integer "id_brew", :null => false
    t.string "flags"
    t.index ["arch_id"], :name => "arch_id"
    t.index ["brew_archive_type_id"], :name => "brew_files_archive_type_ibfk"
    t.index ["brew_build_id"], :name => "brew_build_id"
    t.index ["id_brew"], :name => "index_brew_files_on_id_brew"
    t.index ["name"], :name => "brew_rpm_name"
    t.index ["package_id"], :name => "package_id"
    t.index ["type"], :name => "index_brew_files_on_type"
    t.foreign_key ["arch_id"], "errata_arches", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "brew_files_ibfk_3"
    t.foreign_key ["brew_archive_type_id"], "brew_archive_types", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "brew_files_archive_type_ibfk"
    t.foreign_key ["brew_build_id"], "brew_builds", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "brew_files_ibfk_1"
    t.foreign_key ["package_id"], "packages", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "brew_files_ibfk_2"
  end

  create_table "brew_file_meta", :force => true do |t|
    t.integer "errata_id", :null => false
    t.integer "brew_file_id", :null => false
    t.string "title"
    t.integer "rank"
    t.index ["brew_file_id"], :name => "brew_file_meta_brew_file_ibfk"
    t.index ["errata_id"], :name => "brew_file_meta_errata_ibfk"
    t.foreign_key ["brew_file_id"], "brew_files", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "brew_file_meta_brew_file_ibfk"
    t.foreign_key ["errata_id"], "errata_main", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "brew_file_meta_errata_ibfk"
  end

  create_table "brew_rpm_name_prefixes", :force => true do |t|
    t.string "text", :null => false
    t.integer "product_id", :null => false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "brew_tags", :force => true do |t|
    t.string "name", :null => false
    t.datetime "created_at", :null => false
    t.index ["name"], :name => "brew_tags_name_key", :unique => true
  end

  create_table "brew_tags_product_versions", :force => true do |t|
    t.integer "product_version_id", :null => false
    t.integer "brew_tag_id", :null => false
    t.index ["brew_tag_id"], :name => "brew_tag_id"
    t.index ["product_version_id"], :name => "product_version_id"
    t.foreign_key ["brew_tag_id"], "brew_tags", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "brew_tags_product_versions_ibfk_2"
    t.foreign_key ["product_version_id"], "product_versions", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "brew_tags_product_versions_ibfk_1"
  end

  create_table "brew_tags_releases", :force => true do |t|
    t.integer "release_id", :null => false
    t.integer "brew_tag_id", :null => false
    t.index ["brew_tag_id"], :name => "brew_tag_id"
    t.index ["release_id"], :name => "release_id"
    t.foreign_key ["brew_tag_id"], "brew_tags", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "brew_tags_releases_ibfk_2"
    t.foreign_key ["release_id"], "releases", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "brew_tags_releases_ibfk_1"
  end

  create_table "bug_dependencies", :force => true do |t|
    t.integer "bug_id", :null => false
    t.integer "blocks_bug_id", :null => false
    t.datetime "created_at"
    t.index ["blocks_bug_id"], :name => "index_bug_dependencies_on_blocks_bug_id"
    t.index ["bug_id", "blocks_bug_id"], :name => "index_bug_dependencies_on_bug_id_and_blocks_bug_id", :unique => true
  end

  create_table "bugs", :force => true do |t|
    t.string "bug_status", :null => false
    t.string "short_desc", :limit => 4000, :null => false
    t.integer "package_id", :null => false
    t.integer "is_private", :null => false
    t.datetime "last_updated"
    t.integer "is_security", :default => 0, :null => false
    t.string "alias", :limit => 3200
    t.integer "was_marked_on_qa", :default => 0, :null => false
    t.string "priority", :default => "med", :null => false
    t.string "bug_severity", :default => "med", :null => false
    t.string "qa_whiteboard", :default => "", :null => false
    t.string "keywords", :default => "", :null => false
    t.string "issuetrackers", :default => "", :null => false
    t.integer "pm_score", :default => 0, :null => false
    t.integer "is_blocker", :default => 0, :null => false
    t.integer "is_exception", :default => 0, :null => false
    t.text "flags", :null => false
    t.text "release_notes", :null => false
    t.datetime "reconciled_at"
    t.string "verified", :default => "", :null => false
    t.index ["alias"], :name => "bugs_alias_idx", :length => {"alias"=>255}
    t.index ["package_id"], :name => "package_id"
    t.foreign_key ["package_id"], "packages", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "bugs_ibfk_1"
  end

  create_table "bugs_releases", :force => true do |t|
    t.integer "release_id", :null => false
    t.integer "bug_id", :null => false
    t.index ["bug_id"], :name => "bug_id"
    t.index ["release_id"], :name => "release_id"
    t.foreign_key ["bug_id"], "bugs", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "bugs_releases_ibfk_2"
    t.foreign_key ["release_id"], "releases", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "bugs_releases_ibfk_1"
  end

  create_table "carbon_copies", :force => true do |t|
    t.integer "errata_id", :null => false
    t.integer "who_id", :null => false
    t.index ["errata_id"], :name => "errata_id"
    t.index ["who_id"], :name => "who"
    t.foreign_key ["errata_id"], "errata_main", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "carbon_copies_ibfk_1"
  end

  create_table "errata_versions", :force => true do |t|
    t.integer "product_id", :null => false
    t.string "name", :null => false
    t.string "description", :limit => 2000
    t.string "rhn_channel_tmpl", :limit => 2000
    t.integer "product_version_id", :null => false
    t.integer "rhel_variant_id"
    t.integer "rhel_release_id", :null => false
    t.string "cpe"
    t.boolean "enabled", :default => true, :null => false
    t.string "tps_stream"
    t.index ["id"], :name => "errata_versions_id_key", :unique => true
    t.index ["name"], :name => "version_name_uniq", :unique => true
    t.index ["product_id"], :name => "product_fk"
    t.index ["product_version_id"], :name => "product_version_id"
    t.index ["rhel_release_id"], :name => "rhel_release_id"
    t.index ["rhel_variant_id"], :name => "rhel_variant_id"
    t.foreign_key ["product_id"], "errata_products", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "product_fk"
    t.foreign_key ["product_version_id"], "product_versions", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "errata_versions_ibfk_3"
    t.foreign_key ["rhel_release_id"], "rhel_releases", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "errata_versions_ibfk_1"
    t.foreign_key ["rhel_variant_id"], "errata_versions", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "errata_versions_ibfk_2"
  end

  create_table "cdn_repos", :force => true do |t|
    t.string "type", :null => false
    t.string "name", :null => false
    t.integer "variant_id", :null => false
    t.integer "arch_id", :null => false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean "has_stable_systems_subscribed", :default => false, :null => false
    t.string "release_type", :default => "PrimaryCdnRepo", :null => false
    t.index ["arch_id"], :name => "arch_id"
    t.index ["name"], :name => "index_cdn_repos_on_name", :unique => true
    t.index ["release_type"], :name => "index_cdn_repos_on_release_type"
    t.index ["variant_id"], :name => "variant_id"
    t.foreign_key ["arch_id"], "errata_arches", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "cdn_repos_ibfk_1"
    t.foreign_key ["variant_id"], "errata_versions", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "cdn_repos_ibfk_2"
  end

  create_table "cdn_repo_links", :force => true do |t|
    t.integer "cdn_repo_id", :null => false
    t.integer "variant_id", :null => false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["cdn_repo_id"], :name => "cdn_repo_id"
    t.index ["variant_id"], :name => "variant_id"
    t.foreign_key ["cdn_repo_id"], "cdn_repos", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "cdn_repo_links_ibfk_3"
    t.foreign_key ["variant_id"], "errata_versions", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "cdn_repo_links_ibfk_1"
  end

  create_table "cdn_repo_packages", :force => true do |t|
    t.integer "cdn_repo_id", :null => false
    t.integer "package_id", :null => false
    t.integer "who_id", :null => false
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
    t.index ["cdn_repo_id", "package_id"], :name => "index_cdn_repo_packages_on_cdn_repo_id_and_package_id", :unique => true
    t.index ["package_id"], :name => "package_id"
    t.index ["who_id"], :name => "who_id"
    t.foreign_key ["cdn_repo_id"], "cdn_repos", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "cdn_repo_packages_ibfk_1"
    t.foreign_key ["package_id"], "packages", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "cdn_repo_packages_ibfk_2"
    t.foreign_key ["who_id"], "users", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "cdn_repo_packages_ibfk_3"
  end

  create_table "cdn_repo_package_tags", :force => true do |t|
    t.integer "cdn_repo_package_id", :null => false
    t.string "tag_template", :null => false
    t.integer "who_id", :null => false
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
    t.integer "variant_id"
    t.index ["cdn_repo_package_id", "tag_template"], :name => "cdn_repo_package_tags_unique_1", :unique => true
    t.index ["who_id"], :name => "who_id"
    t.foreign_key ["cdn_repo_package_id"], "cdn_repo_packages", ["id"], :on_update => :restrict, :on_delete => :cascade, :name => "cdn_repo_package_tags_ibfk_1"
    t.foreign_key ["who_id"], "users", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "cdn_repo_package_tags_ibfk_2"
  end

  create_table "channels", :force => true do |t|
    t.string "name", :null => false
    t.string "type", :null => false
    t.integer "variant_id", :null => false
    t.integer "arch_id", :null => false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean "has_stable_systems_subscribed", :default => false, :null => false
    t.index ["arch_id"], :name => "arch_id"
    t.index ["variant_id"], :name => "variant_id"
    t.foreign_key ["arch_id"], "errata_arches", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "channels_ibfk_1"
    t.foreign_key ["variant_id"], "errata_versions", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "channels_ibfk_2"
  end

  create_table "channel_links", :force => true do |t|
    t.integer "channel_id", :null => false
    t.integer "variant_id", :null => false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["channel_id"], :name => "channel_id"
    t.index ["variant_id"], :name => "variant_id"
    t.foreign_key ["channel_id"], "channels", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "channel_links_ibfk_3"
    t.foreign_key ["variant_id"], "errata_versions", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "channel_links_ibfk_1"
  end

  create_table "info_requests", :force => true do |t|
    t.integer "errata_id", :null => false
    t.integer "state_index_id", :null => false
    t.integer "who_id", :null => false
    t.integer "info_role", :null => false
    t.string "summary", :null => false
    t.string "description", :limit => 4000, :null => false
    t.boolean "is_active", :null => false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["errata_id"], :name => "index_info_requests_on_errata_id"
  end

  create_table "comments", :force => true do |t|
    t.integer "errata_id", :null => false
    t.integer "who_id", :null => false
    t.datetime "created_at", :null => false
    t.text "text", :null => false
    t.string "type", :default => "Comment", :null => false
    t.integer "state_index_id"
    t.integer "blocking_issue_id"
    t.integer "info_request_id"
    t.index ["blocking_issue_id"], :name => "blocking_issue_id"
    t.index ["errata_id"], :name => "comments_errata_idx"
    t.index ["info_request_id"], :name => "info_request_id"
    t.index ["state_index_id"], :name => "state_index_id"
    t.index ["who_id"], :name => "who"
    t.foreign_key ["blocking_issue_id"], "blocking_issues", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "comments_ibfk_4"
    t.foreign_key ["errata_id"], "errata_main", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "comments_ibfk_1"
    t.foreign_key ["info_request_id"], "info_requests", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "comments_ibfk_5"
    t.foreign_key ["state_index_id"], "state_indices", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "comments_ibfk_3"
  end

  create_table "container_contents", :force => true do |t|
    t.integer "brew_build_id", :null => false
    t.string "mxor_updated_at"
    t.index ["brew_build_id"], :name => "brew_build_id"
    t.foreign_key ["brew_build_id"], "brew_builds", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "container_contents_ibfk_1"
  end

  create_table "container_repos", :force => true do |t|
    t.integer "container_content_id", :null => false
    t.string "name", :null => false
    t.integer "cdn_repo_id"
    t.string "tags", :limit => 4000
    t.text "comparison"
    t.index ["cdn_repo_id"], :name => "cdn_repo_id"
    t.index ["container_content_id"], :name => "container_content_id"
    t.index ["name"], :name => "name"
    t.foreign_key ["cdn_repo_id"], "cdn_repos", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "container_repos_ibfk_2"
    t.foreign_key ["container_content_id"], "container_contents", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "container_repos_ibfk_1"
  end

  create_table "container_repo_errata", :force => true do |t|
    t.integer "container_repo_id", :null => false
    t.integer "errata_id", :null => false
    t.index ["container_repo_id"], :name => "container_repo_id"
    t.index ["errata_id"], :name => "errata_id"
    t.foreign_key ["container_repo_id"], "container_repos", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "container_repo_errata_ibfk_1"
    t.foreign_key ["errata_id"], "errata_main", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "container_repo_errata_ibfk_2"
  end

  create_table "cves", :force => true do |t|
    t.string "name", :null => false
    t.integer "bug_id"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
    t.index ["bug_id"], :name => "bug_id"
    t.foreign_key ["bug_id"], "bugs", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "cves_ibfk_1"
  end

  create_table "delayed_jobs", :force => true do |t|
    t.integer "priority", :default => 0
    t.integer "attempts", :default => 0
    t.text "handler", :limit => 16777215
    t.text "last_error"
    t.datetime "run_at"
    t.datetime "locked_at"
    t.datetime "failed_at"
    t.string "locked_by"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "dirty_records", :force => true do |t|
    t.integer "record_id", :null => false
    t.string "status"
    t.string "type", :null => false
    t.datetime "last_updated", :null => false
    t.index ["record_id", "status"], :name => "dirty_records_id_and_status_idx"
    t.index ["record_id"], :name => "index_dirty_records_on_record_id"
  end

  create_table "dropped_bugs", :force => true do |t|
    t.integer "errata_id", :null => false
    t.integer "bug_id", :null => false
    t.integer "who_id", :null => false
    t.integer "state_index_id", :null => false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["bug_id"], :name => "bug_id"
    t.index ["errata_id"], :name => "errata_id"
    t.index ["state_index_id"], :name => "state_index_id"
    t.index ["who_id"], :name => "who"
    t.foreign_key ["bug_id"], "bugs", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "dropped_bugs_ibfk_3"
    t.foreign_key ["errata_id"], "errata_main", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "dropped_bugs_ibfk_2"
    t.foreign_key ["state_index_id"], "state_indices", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "dropped_bugs_ibfk_1"
  end

  create_table "jira_security_levels", :force => true do |t|
    t.string "name", :null => false
    t.integer "id_jira", :null => false
    t.string "effect", :limit => 64, :null => false
  end

  create_table "jira_issues", :force => true do |t|
    t.integer "id_jira", :null => false
    t.string "key", :null => false
    t.string "summary", :limit => 4000, :null => false
    t.string "status", :null => false
    t.integer "jira_security_level_id"
    t.datetime "updated", :null => false
    t.string "labels", :default => "[]", :null => false
    t.string "priority"
    t.index ["id_jira"], :name => "jira_issues_id_jira_idx", :unique => true
    t.index ["jira_security_level_id"], :name => "jira_issues_jira_security_level_id_fk"
    t.index ["key"], :name => "jira_issues_key_idx"
    t.foreign_key ["jira_security_level_id"], "jira_security_levels", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "jira_issues_jira_security_level_id_fk"
  end

  create_table "dropped_jira_issues", :force => true do |t|
    t.integer "jira_issue_id", :null => false
    t.integer "errata_id", :null => false
    t.integer "who_id", :null => false
    t.integer "state_index_id", :null => false
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
    t.index ["errata_id"], :name => "index_dropped_jira_issues_on_errata_id"
    t.index ["jira_issue_id"], :name => "dropped_jira_issues_jira_issue_id_fk"
    t.index ["state_index_id"], :name => "dropped_jira_issues_state_index_id_fk"
    t.index ["who_id"], :name => "index_dropped_jira_issues_on_who_id"
    t.foreign_key ["errata_id"], "errata_main", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "dropped_jira_issues_ibfk_1"
    t.foreign_key ["jira_issue_id"], "jira_issues", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "dropped_jira_issues_jira_issue_id_fk"
    t.foreign_key ["state_index_id"], "state_indices", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "dropped_jira_issues_state_index_id_fk"
    t.foreign_key ["who_id"], "users", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "dropped_jira_issues_ibfk_2"
  end

  create_table "errata_activities", :force => true do |t|
    t.integer "errata_id", :null => false
    t.integer "who_id", :null => false
    t.datetime "created_at", :null => false
    t.string "what", :null => false
    t.string "removed"
    t.string "added"
    t.index ["errata_id", "what"], :name => "errata_activity_type"
    t.index ["who_id"], :name => "who"
    t.foreign_key ["errata_id"], "errata_main", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "errata_activities_ibfk_1"
  end

  create_table "errata_brew_mappings", :force => true do |t|
    t.integer "errata_id", :null => false
    t.integer "brew_build_id", :null => false
    t.string "build_tag"
    t.integer "product_version_id", :null => false
    t.integer "package_id", :null => false
    t.integer "current", :default => 1, :null => false
    t.datetime "created_at", :null => false
    t.integer "spin_version", :default => 0, :null => false
    t.integer "shipped", :default => 0, :null => false
    t.datetime "updated_at"
    t.integer "added_index_id"
    t.integer "removed_index_id"
    t.integer "brew_archive_type_id"
    t.string "flags", :default => "--- !ruby/object:Set \nhash: {}\n\n", :null => false
    t.boolean "product_listings_mismatch_ack", :default => false
    t.index ["added_index_id"], :name => "added_index_id"
    t.index ["brew_archive_type_id"], :name => "errata_brew_mappings_archive_type_ibfk"
    t.index ["brew_build_id"], :name => "brew_build_id"
    t.index ["errata_id"], :name => "errata_id"
    t.index ["package_id"], :name => "package_id"
    t.index ["product_version_id"], :name => "product_version_id"
    t.index ["removed_index_id"], :name => "removed_index_id"
    t.foreign_key ["added_index_id"], "state_indices", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "errata_brew_mappings_ibfk_5"
    t.foreign_key ["brew_archive_type_id"], "brew_archive_types", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "errata_brew_mappings_archive_type_ibfk"
    t.foreign_key ["brew_build_id"], "brew_builds", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "errata_brew_mappings_ibfk_2"
    t.foreign_key ["errata_id"], "errata_main", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "errata_brew_mappings_ibfk_1"
    t.foreign_key ["package_id"], "packages", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "errata_brew_mappings_ibfk_4"
    t.foreign_key ["product_version_id"], "product_versions", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "errata_brew_mappings_ibfk_3"
    t.foreign_key ["removed_index_id"], "state_indices", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "errata_brew_mappings_ibfk_6"
  end

  create_table "errata_bug_map", :id => false, :force => true do |t|
    t.integer "errata_id", :null => false
    t.integer "bug_id", :null => false
    t.datetime "created_at", :null => false
    t.index ["bug_id", "errata_id"], :name => "errata_bug_map_idx"
    t.index ["errata_id"], :name => "errata_bug_fk"
    t.foreign_key ["bug_id"], "bugs", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "bug_id_fk"
    t.foreign_key ["errata_id"], "errata_main", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "errata_bug_fk"
  end

  create_table "errata_content", :force => true do |t|
    t.integer "errata_id", :null => false
    t.text "topic", :null => false
    t.text "description", :null => false
    t.text "solution", :null => false
    t.string "keywords", :limit => 4000, :null => false
    t.string "obsoletes", :limit => 4000
    t.string "cve", :limit => 4000
    t.text "packages"
    t.text "multilib"
    t.string "crossref", :limit => 4000
    t.string "reference", :limit => 4000
    t.text "how_to_test"
    t.integer "doc_reviewer_id", :default => 0, :null => false
    t.datetime "updated_at", :null => false
    t.integer "revision_count", :default => 1, :null => false
    t.datetime "doc_review_due_at"
    t.text "text_only_cpe"
    t.text "product_version_text"
    t.index ["doc_reviewer_id"], :name => "doc_reviewer_fk"
    t.index ["errata_id"], :name => "errata_content_idx", :unique => true
    t.foreign_key ["doc_reviewer_id"], "users", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "doc_reviewer_fk"
    t.foreign_key ["errata_id"], "errata_main", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "errata_content_fk"
  end

  create_table "errata_cve_maps", :force => true do |t|
    t.integer "errata_id", :null => false
    t.integer "cve_id", :null => false
    t.datetime "created_at", :null => false
    t.index ["cve_id"], :name => "cve_id"
    t.index ["errata_id"], :name => "errata_id"
    t.foreign_key ["cve_id"], "cves", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "errata_cve_maps_ibfk_2"
    t.foreign_key ["errata_id"], "errata_main", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "errata_cve_maps_ibfk_1"
  end

  create_table "errata_files", :force => true do |t|
    t.integer "errata_id", :null => false
    t.integer "version_id", :null => false
    t.integer "arch_id", :null => false
    t.string "devel_file", :limit => 4000, :null => false
    t.string "ftp_file", :limit => 4000, :null => false
    t.string "md5sum", :limit => 4000, :null => false
    t.datetime "change_when", :null => false
    t.integer "current", :default => 1, :null => false
    t.integer "who", :null => false
    t.string "signed", :default => "none", :null => false
    t.string "rhn_channels", :limit => 2000
    t.string "rhn_beta_channels", :limit => 2000
    t.string "collection", :limit => 256
    t.integer "released", :default => 0, :null => false
    t.date "rhn_pkgupload"
    t.string "rhn_shadow_channels", :limit => 2000
    t.integer "prior", :default => 0, :null => false
    t.string "epoch"
    t.integer "package_id", :null => false
    t.integer "brew_rpm_id", :default => -1, :null => false
    t.integer "brew_build_id"
    t.index ["arch_id", "version_id", "errata_id", "id"], :name => "errata_files_idx"
    t.index ["brew_build_id"], :name => "brew_build_id"
    t.index ["change_when", "errata_id"], :name => "errata_files_change_idx"
    t.index ["current", "errata_id"], :name => "errata_files_current_idx"
    t.index ["errata_id"], :name => "errata_files_fk"
    t.index ["package_id", "current", "errata_id"], :name => "errata_package_index"
    t.index ["version_id"], :name => "version_fk"
    t.index ["who"], :name => "who_fk"
    t.foreign_key ["arch_id"], "errata_arches", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "arch_fk"
    t.foreign_key ["brew_build_id"], "brew_builds", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "errata_files_ibfk_1"
    t.foreign_key ["errata_id"], "errata_main", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "errata_files_fk"
    t.foreign_key ["package_id"], "packages", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "package_fk"
    t.foreign_key ["version_id"], "errata_versions", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "version_fk"
    t.foreign_key ["who"], "users", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "who_fk"
  end

  create_table "errata_filters", :force => true do |t|
    t.string "type", :null => false
    t.string "name", :null => false
    t.text "filter_params"
    t.integer "user_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "display_order"
  end

  create_table "errata_priority", :id => false, :force => true do |t|
    t.string "value", :null => false
  end

  create_table "errata_severity", :id => false, :force => true do |t|
    t.string "value", :null => false
  end

  create_table "errata_types", :force => true do |t|
    t.string "name", :null => false
    t.string "description", :null => false
    t.index ["name"], :name => "index_errata_types_on_name", :unique => true
  end

  create_table "external_test_runs", :force => true do |t|
    t.integer "external_test_type_id", :null => false
    t.integer "errata_id", :null => false
    t.integer "brew_build_id"
    t.boolean "active", :default => true, :null => false
    t.integer "superseded_by_id"
    t.string "status", :default => "PENDING", :null => false
    t.integer "external_id"
    t.string "external_status"
    t.string "external_message"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text "external_data"
  end

  create_table "external_test_types", :force => true do |t|
    t.string "name", :null => false
    t.string "display_name", :null => false
    t.string "prod_run_url", :null => false
    t.string "test_run_url"
    t.string "info_url"
    t.boolean "active", :default => true, :null => false
    t.integer "sort_key", :default => 0
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "tab_name", :null => false
  end

  create_table "state_transition_guards", :force => true do |t|
    t.integer "state_machine_rule_set_id", :null => false
    t.integer "state_transition_id", :null => false
    t.string "type", :null => false
    t.string "guard_type", :default => "block", :null => false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "external_tests_guard_test_types", :force => true do |t|
    t.integer "external_tests_guard_id", :null => false
    t.integer "external_test_type_id", :null => false
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
    t.index ["external_test_type_id"], :name => "type_ibfk"
    t.index ["external_tests_guard_id"], :name => "guard_ibfk"
    t.foreign_key ["external_test_type_id"], "external_test_types", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "type_ibfk"
    t.foreign_key ["external_tests_guard_id"], "state_transition_guards", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "guard_ibfk"
  end

  create_table "filed_bugs", :force => true do |t|
    t.integer "errata_id", :null => false
    t.integer "bug_id", :null => false
    t.datetime "created_at", :null => false
    t.integer "user_id", :null => false
    t.integer "state_index_id"
    t.index ["bug_id"], :name => "bug_id"
    t.index ["errata_id", "bug_id", "created_at"], :name => "filed_bugs_idx"
    t.index ["state_index_id"], :name => "state_index_id"
    t.index ["user_id"], :name => "user_id"
    t.foreign_key ["bug_id"], "bugs", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "filed_bugs_ibfk_2"
    t.foreign_key ["errata_id"], "errata_main", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "filed_bugs_ibfk_1"
    t.foreign_key ["state_index_id"], "state_indices", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "filed_bugs_ibfk_4"
    t.foreign_key ["user_id"], "users", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "filed_bugs_ibfk_3"
  end

  create_table "filed_jira_issues", :force => true do |t|
    t.integer "jira_issue_id", :null => false
    t.integer "errata_id", :null => false
    t.integer "user_id", :null => false
    t.integer "state_index_id", :null => false
    t.datetime "created_at", :null => false
    t.index ["errata_id"], :name => "index_filed_jira_issues_on_errata_id"
    t.index ["jira_issue_id"], :name => "filed_jira_issues_jira_issue_id_fk"
    t.index ["state_index_id"], :name => "filed_jira_issues_state_index_id_fk"
    t.index ["user_id"], :name => "filed_jira_issues_user_id_fk"
    t.foreign_key ["errata_id"], "errata_main", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "filed_jira_issues_ibfk_1"
    t.foreign_key ["jira_issue_id"], "jira_issues", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "filed_jira_issues_jira_issue_id_fk"
    t.foreign_key ["state_index_id"], "state_indices", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "filed_jira_issues_state_index_id_fk"
    t.foreign_key ["user_id"], "users", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "filed_jira_issues_user_id_fk"
  end

  create_table "ftp_exclusions", :force => true do |t|
    t.integer "package_id", :null => false
    t.integer "product_id", :null => false
    t.integer "product_version_id"
    t.index ["package_id"], :name => "package_id"
    t.index ["product_id"], :name => "product_id"
    t.index ["product_version_id"], :name => "product_version_id"
    t.foreign_key ["package_id"], "packages", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "ftp_exclusions_ibfk_1"
    t.foreign_key ["product_id"], "errata_products", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "ftp_exclusions_ibfk_2"
    t.foreign_key ["product_version_id"], "product_versions", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "ftp_exclusions_ibfk_3"
  end

  create_table "job_tracker_delayed_maps", :force => true do |t|
    t.integer "delayed_job_id", :null => false
    t.integer "job_tracker_id", :null => false
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  create_table "job_trackers", :force => true do |t|
    t.string "name", :null => false
    t.string "description", :null => false
    t.integer "user_id", :null => false
    t.string "state", :default => "RUNNING", :null => false
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
    t.integer "max_attempts"
    t.integer "total_job_count", :null => false
    t.boolean "send_mail", :default => true, :null => false
  end

  create_table "live_advisory_names", :force => true do |t|
    t.integer "errata_id", :null => false
    t.integer "year", :null => false
    t.integer "live_id", :null => false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["errata_id"], :name => "index_live_advisory_names_on_errata_id", :unique => true
    t.index ["year", "live_id"], :name => "index_live_advisory_names_on_year_and_live_id", :unique => true
  end

  create_table "md5sums", :force => true do |t|
    t.integer "brew_file_id", :null => false
    t.integer "sig_key_id", :null => false
    t.datetime "created_at", :null => false
    t.string "value", :null => false
    t.index ["brew_file_id"], :name => "brew_rpm_id"
    t.index ["sig_key_id", "brew_file_id"], :name => "md5sum_sig_rpm_idx"
    t.index ["value"], :name => "md5sums_value_idx"
    t.foreign_key ["brew_file_id"], "brew_files", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "md5sums_brew_file_fk"
    t.foreign_key ["sig_key_id"], "sig_keys", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "md5sums_ibfk_1"
  end

  create_table "multi_product_cdn_repo_maps", :force => true do |t|
    t.integer "origin_cdn_repo_id", :null => false
    t.integer "origin_product_version_id", :null => false
    t.integer "destination_cdn_repo_id", :null => false
    t.integer "destination_product_version_id", :null => false
    t.integer "package_id", :null => false
    t.integer "user_id", :null => false
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  create_table "multi_product_cdn_repo_map_subscriptions", :force => true do |t|
    t.integer "multi_product_cdn_repo_map_id", :null => false
    t.integer "subscriber_id", :null => false
    t.integer "who_id", :null => false
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
    t.index ["multi_product_cdn_repo_map_id"], :name => "mp_cdn_repo_map_fk"
    t.index ["subscriber_id"], :name => "mp_cdn_repo_subscriber_fk"
    t.index ["who_id"], :name => "mp_cdn_repo_who_fk"
    t.foreign_key ["multi_product_cdn_repo_map_id"], "multi_product_cdn_repo_maps", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "mp_cdn_repo_map_fk"
    t.foreign_key ["subscriber_id"], "users", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "mp_cdn_repo_subscriber_fk"
    t.foreign_key ["who_id"], "users", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "mp_cdn_repo_who_fk"
  end

  create_table "multi_product_channel_maps", :force => true do |t|
    t.integer "origin_channel_id", :null => false
    t.integer "origin_product_version_id", :null => false
    t.integer "destination_channel_id", :null => false
    t.integer "destination_product_version_id", :null => false
    t.integer "package_id", :null => false
    t.integer "user_id", :null => false
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  create_table "multi_product_channel_map_subscriptions", :force => true do |t|
    t.integer "multi_product_channel_map_id", :null => false
    t.integer "subscriber_id", :null => false
    t.integer "who_id", :null => false
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
    t.index ["multi_product_channel_map_id"], :name => "mp_channel_map_fk"
    t.index ["subscriber_id"], :name => "mp_channel_subscriber_fk"
    t.index ["who_id"], :name => "mp_channel_who_fk"
    t.foreign_key ["multi_product_channel_map_id"], "multi_product_channel_maps", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "mp_channel_map_fk"
    t.foreign_key ["subscriber_id"], "users", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "mp_channel_subscriber_fk"
    t.foreign_key ["who_id"], "users", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "mp_channel_who_fk"
  end

  create_table "nitrate_test_plans", :force => true do |t|
    t.integer "errata_id", :null => false
    t.integer "who_id", :null => false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["errata_id"], :name => "errata_id"
    t.index ["who_id"], :name => "who"
    t.foreign_key ["errata_id"], "errata_main", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "nitrate_test_plans_ibfk_1"
  end

  create_table "optional_channel_to_layered_maps", :force => true do |t|
    t.integer "optional_channel_id", :null => false
    t.integer "layered_channel_id", :null => false
    t.integer "package_id", :null => false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["layered_channel_id"], :name => "layered_channel_id"
    t.index ["optional_channel_id"], :name => "optional_channel_id"
    t.foreign_key ["layered_channel_id"], "channels", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "optional_channel_to_layered_maps_ibfk_2"
    t.foreign_key ["optional_channel_id"], "channels", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "optional_channel_to_layered_maps_ibfk_1"
  end

  create_table "package_restrictions", :force => true do |t|
    t.integer "package_id", :null => false
    t.integer "variant_id", :null => false
    t.integer "who_id", :null => false
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
    t.index ["package_id"], :name => "package_restrictions_package_id_fk"
    t.index ["variant_id"], :name => "package_restrictions_variant_id_fk"
    t.index ["who_id"], :name => "package_restrictions_who_id_fk"
    t.foreign_key ["package_id"], "packages", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "package_restrictions_package_id_fk"
    t.foreign_key ["variant_id"], "errata_versions", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "package_restrictions_variant_id_fk"
    t.foreign_key ["who_id"], "users", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "package_restrictions_who_id_fk"
  end

  create_table "pdc_errata_files", :force => true do |t|
    t.integer "errata_id", :null => false
    t.integer "pdc_variant_id", :null => false
    t.integer "arch_id", :null => false
    t.string "devel_file", :limit => 4000, :null => false
    t.string "ftp_file", :limit => 4000, :null => false
    t.string "md5sum", :limit => 4000, :null => false
    t.datetime "change_when", :null => false
    t.integer "current", :default => 1, :null => false
    t.integer "who", :null => false
    t.string "signed", :default => "none", :null => false
    t.string "rhn_channels", :limit => 2000
    t.string "rhn_beta_channels", :limit => 2000
    t.string "collection", :limit => 256
    t.integer "released", :default => 0, :null => false
    t.date "rhn_pkgupload"
    t.string "rhn_shadow_channels", :limit => 2000
    t.integer "prior", :default => 0, :null => false
    t.string "epoch"
    t.integer "package_id", :null => false
    t.integer "brew_rpm_id", :default => -1, :null => false
    t.integer "brew_build_id"
    t.index ["arch_id", "pdc_variant_id", "errata_id", "id"], :name => "pdc_errata_files_idx"
    t.index ["brew_build_id"], :name => "index_pdc_errata_files_on_brew_build_id"
    t.index ["change_when", "errata_id"], :name => "index_pdc_errata_files_on_change_when_and_errata_id"
    t.index ["current", "errata_id"], :name => "index_pdc_errata_files_on_current_and_errata_id"
    t.index ["errata_id"], :name => "index_pdc_errata_files_on_errata_id"
    t.index ["package_id", "current", "errata_id"], :name => "index_pdc_errata_files_on_package_id_and_current_and_errata_id"
    t.index ["pdc_variant_id"], :name => "index_pdc_errata_files_on_pdc_variant_id"
    t.index ["who"], :name => "index_pdc_errata_files_on_who"
    t.foreign_key ["arch_id"], "errata_arches", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "pdc_errata_files_ibfk_1"
    t.foreign_key ["brew_build_id"], "brew_builds", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "pdc_errata_files_ibfk_2"
    t.foreign_key ["errata_id"], "errata_main", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "pdc_errata_files_ibfk_3"
    t.foreign_key ["package_id"], "packages", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "pdc_errata_files_ibfk_4"
    t.foreign_key ["pdc_variant_id"], "pdc_resources", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "pdc_errata_files_ibfk_5"
    t.foreign_key ["who"], "users", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "pdc_errata_files_ibfk_6"
  end

  create_table "pdc_errata_releases", :force => true do |t|
    t.integer "errata_id"
    t.integer "pdc_release_id"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
    t.index ["errata_id"], :name => "index_pdc_errata_releases_on_errata_id"
    t.index ["pdc_release_id"], :name => "index_pdc_errata_releases_on_pdc_release_id"
    t.foreign_key ["errata_id"], "errata_main", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "pdc_errata_releases_ibfk_1"
    t.foreign_key ["pdc_release_id"], "pdc_resources", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "pdc_errata_releases_ibfk_2"
  end

  create_table "pdc_errata_release_builds", :force => true do |t|
    t.integer "pdc_errata_release_id"
    t.integer "brew_build_id"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
    t.integer "current", :default => 1, :null => false
    t.integer "brew_archive_type_id"
    t.string "flags", :default => "--- !ruby/object:Set \nhash: {}\n\n", :null => false
    t.integer "removed_index_id"
    t.integer "added_index_id"
    t.boolean "shipped", :default => false, :null => false
    t.index ["added_index_id"], :name => "index_pdc_errata_release_builds_on_added_index_id"
    t.index ["brew_archive_type_id"], :name => "pdc_errata_release_builds_archive_type_ibfk"
    t.index ["brew_build_id"], :name => "index_pdc_errata_release_builds_on_brew_build_id"
    t.index ["pdc_errata_release_id"], :name => "index_pdc_errata_release_builds_on_pdc_errata_release_id"
    t.index ["removed_index_id"], :name => "index_pdc_errata_release_builds_on_removed_index_id"
    t.foreign_key ["added_index_id"], "state_indices", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "pdc_errata_release_builds_ibfk_4"
    t.foreign_key ["brew_archive_type_id"], "brew_archive_types", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "pdc_errata_release_builds_archive_type_ibfk"
    t.foreign_key ["brew_build_id"], "brew_builds", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "pdc_errata_release_builds_ibfk_2"
    t.foreign_key ["pdc_errata_release_id"], "pdc_errata_releases", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "pdc_errata_release_builds_ibfk_1"
    t.foreign_key ["removed_index_id"], "state_indices", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "pdc_errata_release_builds_ibfk_3"
  end

  create_table "pdc_product_listing_caches", :force => true do |t|
    t.integer "pdc_release_id"
    t.integer "brew_build_id"
    t.text "cache", :limit => 16777215
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
    t.index ["brew_build_id"], :name => "index_pdc_product_listing_caches_on_brew_build_id"
    t.index ["pdc_release_id"], :name => "index_pdc_product_listing_caches_on_pdc_release_id"
    t.foreign_key ["brew_build_id"], "brew_builds", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "pdc_product_listing_caches_ibfk_2"
    t.foreign_key ["pdc_release_id"], "pdc_resources", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "pdc_product_listing_caches_ibfk_1"
  end

  create_table "pdc_released_packages", :force => true do |t|
    t.integer "pdc_variant_id", :null => false
    t.integer "package_id", :null => false
    t.integer "arch_id", :null => false
    t.string "full_path", :null => false
    t.integer "pdc_release_id", :null => false
    t.integer "current", :default => 1
    t.datetime "updated_at"
    t.string "rpm_name"
    t.integer "brew_rpm_id"
    t.integer "brew_build_id"
    t.datetime "created_at"
    t.integer "errata_id"
    t.index ["arch_id", "package_id", "pdc_variant_id"], :name => "pdc_released_package_variant_idx"
    t.index ["brew_build_id"], :name => "brew_build_id"
    t.index ["brew_rpm_id"], :name => "brew_rpm_id"
    t.index ["errata_id"], :name => "errata_released_package_idx"
    t.index ["package_id"], :name => "package_id"
    t.index ["pdc_release_id", "current"], :name => "released_package_pr_index"
    t.index ["pdc_variant_id"], :name => "pdc_variant_id"
    t.foreign_key ["arch_id"], "errata_arches", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "pdc_released_packages_ibfk_1"
    t.foreign_key ["brew_build_id"], "brew_builds", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "pdc_released_packages_ibfk_2"
    t.foreign_key ["brew_rpm_id"], "brew_files", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "pdc_released_packages_ibfk_3"
    t.foreign_key ["errata_id"], "errata_main", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "pdc_released_packages_ibfk_4"
    t.foreign_key ["package_id"], "packages", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "pdc_released_packages_ibfk_5"
    t.foreign_key ["pdc_release_id"], "pdc_resources", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "pdc_released_packages_ibfk_6"
    t.foreign_key ["pdc_variant_id"], "pdc_resources", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "pdc_released_packages_ibfk_7"
  end

  create_table "pdc_releases_releases", :id => false, :force => true do |t|
    t.integer "pdc_release_id"
    t.integer "release_id"
    t.index ["pdc_release_id"], :name => "pdc_releases_releases_ibfk_1"
    t.index ["release_id", "pdc_release_id"], :name => "index_pdc_releases_releases_on_release_id_and_pdc_release_id"
    t.foreign_key ["pdc_release_id"], "pdc_resources", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "pdc_releases_releases_ibfk_1"
    t.foreign_key ["release_id"], "releases", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "pdc_releases_releases_ibfk_2"
  end

  create_table "product_listing_caches", :force => true do |t|
    t.integer "product_version_id", :null => false
    t.integer "brew_build_id", :null => false
    t.datetime "created_at", :null => false
    t.text "cache", :limit => 16777215, :null => false
    t.index ["brew_build_id", "product_version_id"], :name => "plc_unique_build_product_idx", :unique => true
    t.index ["brew_build_id"], :name => "brew_build_id"
    t.index ["product_version_id"], :name => "product_version_id"
    t.foreign_key ["brew_build_id"], "brew_builds", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "product_listing_caches_ibfk_2"
    t.foreign_key ["product_version_id"], "product_versions", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "product_listing_caches_ibfk_1"
  end

  create_table "product_versions_releases", :id => false, :force => true do |t|
    t.integer "release_id", :null => false
    t.integer "product_version_id", :null => false
    t.index ["product_version_id"], :name => "product_version_id"
    t.index ["release_id", "product_version_id"], :name => "product_versions_releases_idx", :unique => true
    t.foreign_key ["product_version_id"], "product_versions", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "product_versions_releases_ibfk_2"
    t.foreign_key ["release_id"], "releases", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "product_versions_releases_ibfk_1"
  end

  create_table "publications", :force => true do |t|
    t.string "type", :null => false
    t.datetime "last_published_at", :null => false
    t.integer "is_out_of_date", :default => 0, :null => false
  end

  create_table "push_jobs", :force => true do |t|
    t.integer "errata_id", :null => false
    t.integer "pushed_by", :null => false
    t.string "type", :null => false
    t.string "status", :default => "READY", :null => false
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
    t.text "log", :null => false
    t.string "pub_options"
    t.string "pre_push_tasks"
    t.string "post_push_tasks"
    t.integer "priority", :default => 0
    t.integer "pub_task_id"
    t.boolean "problem_ticket_filed", :default => false
    t.integer "push_target_id", :null => false
    t.index ["errata_id", "type"], :name => "index_push_jobs_on_errata_id_and_type"
    t.index ["pub_task_id"], :name => "rhn_push_jobs_pub_task_id_index"
  end

  create_table "push_targets", :force => true do |t|
    t.string "name", :null => false
    t.string "description", :null => false
    t.string "push_type", :null => false
    t.integer "is_internal", :default => 0, :null => false
    t.integer "boolean", :default => 0, :null => false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "record_logs", :force => true do |t|
    t.string "message", :null => false
    t.string "severity", :null => false
    t.integer "record_id", :null => false
    t.string "type", :null => false
    t.integer "user_id"
    t.datetime "created_at", :null => false
  end

  create_table "release_components", :force => true do |t|
    t.integer "package_id", :null => false
    t.integer "release_id", :null => false
    t.datetime "created_at", :null => false
    t.integer "errata_id"
    t.index ["package_id"], :name => "package_id"
    t.index ["release_id"], :name => "release_id"
    t.foreign_key ["package_id"], "packages", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "release_components_ibfk_2"
    t.foreign_key ["release_id"], "releases", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "release_components_ibfk_1"
  end

  create_table "release_milestones", :force => true do |t|
    t.string "name", :null => false
    t.integer "release_id", :null => false
    t.date "due_date", :null => false
    t.index ["release_id"], :name => "release_id"
    t.foreign_key ["release_id"], "releases", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "release_milestones_ibfk_1"
  end

  create_table "released_package_updates", :force => true do |t|
    t.integer "who_id", :null => false
    t.string "reason", :limit => 1000, :null => false
    t.text "user_input", :null => false
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
    t.index ["who_id"], :name => "index_released_package_updates_on_who_id"
    t.foreign_key ["who_id"], "users", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "released_package_updates_ibfk_1"
  end

  create_table "released_packages", :force => true do |t|
    t.integer "version_id", :null => false
    t.integer "package_id", :null => false
    t.integer "arch_id", :null => false
    t.string "full_path", :null => false
    t.integer "product_version_id", :null => false
    t.integer "current", :default => 1
    t.datetime "updated_at"
    t.string "rpm_name"
    t.integer "brew_rpm_id"
    t.integer "brew_build_id"
    t.datetime "created_at"
    t.integer "errata_id"
    t.index ["arch_id", "package_id", "version_id"], :name => "released_package_version_idx"
    t.index ["brew_build_id"], :name => "brew_build_id"
    t.index ["brew_rpm_id"], :name => "brew_rpm_id"
    t.index ["errata_id"], :name => "errata_released_package_idx"
    t.index ["package_id"], :name => "package_id"
    t.index ["product_version_id", "current"], :name => "released_package_pv_index"
    t.index ["version_id"], :name => "version_id"
    t.foreign_key ["arch_id"], "errata_arches", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "released_packages_ibfk_3"
    t.foreign_key ["brew_build_id"], "brew_builds", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "released_packages_ibfk_5"
    t.foreign_key ["brew_rpm_id"], "brew_files", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "released_packages_ibfk_7"
    t.foreign_key ["errata_id"], "errata_main", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "released_packages_ibfk_6"
    t.foreign_key ["package_id"], "packages", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "released_packages_ibfk_2"
    t.foreign_key ["product_version_id"], "product_versions", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "released_packages_ibfk_4"
    t.foreign_key ["version_id"], "errata_versions", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "released_packages_ibfk_1"
  end

  create_table "released_package_audits", :force => true do |t|
    t.integer "released_package_id"
    t.integer "released_package_update_id", :null => false
    t.integer "pdc_released_package_id"
    t.index ["pdc_released_package_id"], :name => "index_released_package_audits_on_pdc_released_package_id"
    t.index ["released_package_id"], :name => "index_released_package_audits_on_released_package_id"
    t.index ["released_package_update_id"], :name => "index_released_package_audits_on_released_package_update_id"
    t.foreign_key ["pdc_released_package_id"], "pdc_released_packages", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "released_package_audits_ibfk_3"
    t.foreign_key ["released_package_id"], "released_packages", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "released_package_audits_ibfk_1"
    t.foreign_key ["released_package_update_id"], "released_package_updates", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "released_package_audits_ibfk_2"
  end

  create_table "variant_push_targets", :force => true do |t|
    t.integer "variant_id", :null => false
    t.integer "push_target_id", :null => false
    t.integer "active_push_target_id", :null => false
    t.integer "who_id", :null => false
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
    t.index ["active_push_target_id"], :name => "variant_push_targets_active_push_target_id_fk"
    t.index ["push_target_id"], :name => "variant_push_targets_push_target_id_fk"
    t.index ["variant_id"], :name => "variant_push_targets_variant_id_fk"
    t.index ["who_id"], :name => "variant_push_targets_who_id_fk"
    t.foreign_key ["active_push_target_id"], "active_push_targets", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "variant_push_targets_active_push_target_id_fk"
    t.foreign_key ["push_target_id"], "push_targets", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "variant_push_targets_push_target_id_fk"
    t.foreign_key ["variant_id"], "errata_versions", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "variant_push_targets_variant_id_fk"
    t.foreign_key ["who_id"], "users", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "variant_push_targets_who_id_fk"
  end

  create_table "restricted_package_dists", :force => true do |t|
    t.integer "package_restriction_id", :null => false
    t.integer "push_target_id", :null => false
    t.integer "variant_push_target_id", :null => false
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
    t.index ["package_restriction_id"], :name => "restricted_package_dists_package_restriction_id_fk"
    t.index ["push_target_id"], :name => "restricted_package_dists_push_target_id_fk"
    t.index ["variant_push_target_id"], :name => "restricted_package_dists_variant_push_target_id_fk"
    t.foreign_key ["package_restriction_id"], "package_restrictions", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "restricted_package_dists_package_restriction_id_fk"
    t.foreign_key ["push_target_id"], "push_targets", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "restricted_package_dists_push_target_id_fk"
    t.foreign_key ["variant_push_target_id"], "variant_push_targets", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "restricted_package_dists_variant_push_target_id_fk"
  end

  create_table "rhn_channels", :force => true do |t|
    t.integer "version_id", :null => false
    t.integer "arch_id", :null => false
    t.integer "product_version_id", :null => false
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
    t.integer "isdefault", :default => 1, :null => false
    t.string "rhn_channel", :limit => 2000, :null => false
    t.string "rhn_beta_channel", :limit => 2000
    t.string "rhn_shadow_channel", :limit => 2000
    t.string "rhn_fastrack_channel", :limit => 2000
    t.string "rhn_eus_channel", :limit => 2000
    t.index ["arch_id"], :name => "arch_id"
    t.index ["product_version_id"], :name => "product_version_id"
    t.index ["version_id"], :name => "version_id"
    t.foreign_key ["arch_id"], "errata_arches", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "rhn_channels_ibfk_2"
    t.foreign_key ["product_version_id"], "product_versions", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "rhn_channels_ibfk_3"
    t.foreign_key ["version_id"], "errata_versions", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "rhn_channels_ibfk_1"
  end

  create_table "rhn_push_jobs", :force => true do |t|
    t.integer "errata_id", :null => false
    t.integer "pushed_by", :null => false
    t.string "push_type", :limit => 10, :null => false
    t.string "status", :default => "STARTED", :null => false
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
    t.text "log", :null => false
    t.index ["errata_id"], :name => "errata_id"
    t.index ["pushed_by"], :name => "pushed_by"
    t.foreign_key ["errata_id"], "errata_main", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "rhn_push_jobs_ibfk_1"
    t.foreign_key ["pushed_by"], "users", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "rhn_push_jobs_ibfk_2"
  end

  create_table "rhts_runs", :force => true do |t|
    t.integer "errata_id"
    t.integer "user_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["errata_id"], :name => "errata_id"
    t.index ["user_id"], :name => "user_id"
    t.foreign_key ["errata_id"], "errata_main", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "rhts_runs_ibfk_1"
    t.foreign_key ["user_id"], "users", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "rhts_runs_ibfk_2"
  end

  create_table "roles", :force => true do |t|
    t.string "name", :null => false
    t.string "description", :limit => 4000, :null => false
    t.string "blocking_issue_target"
    t.string "info_request_target"
    t.string "rt_queue"
    t.string "rt_email"
    t.string "irc_channel"
    t.string "team_name"
    t.boolean "notify_same_role", :default => true, :null => false
    t.index ["name"], :name => "index_user_groups_on_name", :unique => true
  end

  create_table "roles_users", :id => false, :force => true do |t|
    t.integer "user_id", :null => false
    t.integer "role_id", :null => false
    t.index ["role_id", "user_id"], :name => "user_group_idx", :unique => true
    t.index ["user_id"], :name => "user_id"
  end

  create_table "rpmdiff_scores", :force => true do |t|
    t.integer "score", :null => false
    t.string "description", :limit => 240, :null => false
    t.string "html_color", :limit => 12, :null => false
  end

  create_table "rpmdiff_runs", :primary_key => "run_id", :force => true do |t|
    t.integer "errata_id", :null => false
    t.string "package_name", :limit => 240, :null => false
    t.string "new_version", :limit => 240, :null => false
    t.string "old_version", :limit => 240, :null => false
    t.string "package_path", :limit => 400
    t.datetime "run_date", :null => false
    t.integer "overall_score", :null => false
    t.string "person", :limit => 240, :null => false
    t.string "errata_nr", :limit => 16
    t.integer "obsolete", :default => 0, :null => false
    t.string "variant", :null => false
    t.integer "errata_file_id"
    t.integer "brew_build_id"
    t.integer "brew_rpm_id"
    t.integer "package_id", :null => false
    t.integer "errata_brew_mapping_id"
    t.integer "last_good_run_id"
    t.integer "pdc_errata_release_build_id"
    t.index ["brew_build_id"], :name => "brew_build_id"
    t.index ["brew_rpm_id"], :name => "brew_rpm_id"
    t.index ["errata_brew_mapping_id"], :name => "errata_brew_mapping_id"
    t.index ["errata_file_id"], :name => "errata_file_id"
    t.index ["errata_id"], :name => "rpmdiff_runs_errata_idx"
    t.index ["last_good_run_id"], :name => "last_good_run_id"
    t.index ["overall_score", "errata_id", "run_id"], :name => "rpmdiff_runs_idx"
    t.index ["package_id"], :name => "package_id"
    t.index ["pdc_errata_release_build_id"], :name => "pdc_errata_release_build_id"
    t.foreign_key ["brew_build_id"], "brew_builds", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "rpmdiff_runs_ibfk_2"
    t.foreign_key ["brew_rpm_id"], "brew_files", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "rpmdiff_runs_ibfk_3"
    t.foreign_key ["errata_brew_mapping_id"], "errata_brew_mappings", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "rpmdiff_runs_ibfk_5"
    t.foreign_key ["errata_file_id"], "errata_files", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "rpmdiff_runs_ibfk_1"
    t.foreign_key ["errata_id"], "errata_main", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "errata_rpmdiff_run_fk"
    t.foreign_key ["last_good_run_id"], "rpmdiff_runs", ["run_id"], :on_update => :restrict, :on_delete => :restrict, :name => "rpmdiff_runs_ibfk_6"
    t.foreign_key ["overall_score"], "rpmdiff_scores", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "rpmdiff_run_score_fk"
    t.foreign_key ["package_id"], "packages", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "rpmdiff_runs_ibfk_4"
    t.foreign_key ["pdc_errata_release_build_id"], "pdc_errata_release_builds", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "rpmdiff_runs_ibfk_7"
  end

  create_table "rpmdiff_tests", :primary_key => "test_id", :force => true do |t|
    t.string "description", :limit => 240, :null => false
    t.string "long_desc", :limit => 240, :null => false
    t.string "wiki_url", :limit => 240, :null => false
  end

  create_table "rpmdiff_results", :primary_key => "result_id", :force => true do |t|
    t.integer "run_id", :null => false
    t.integer "test_id", :null => false
    t.integer "score", :null => false
    t.text "log", :limit => 16777215
    t.integer "need_push_priv", :default => 0, :null => false
    t.string "can_approve_waiver"
    t.index ["run_id"], :name => "run_id"
    t.index ["score", "test_id", "run_id", "result_id"], :name => "rpmdiff_results_idx"
    t.index ["test_id", "run_id"], :name => "rpmdiff_run_test_unique", :unique => true
    t.foreign_key ["run_id"], "rpmdiff_runs", ["run_id"], :on_update => :restrict, :on_delete => :restrict, :name => "rpmdiff_results_ibfk_1"
    t.foreign_key ["score"], "rpmdiff_scores", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "rpmdiff_result_score_fk"
    t.foreign_key ["test_id"], "rpmdiff_tests", ["test_id"], :on_update => :restrict, :on_delete => :restrict, :name => "rpmdiff_results_ibfk_2"
  end

  create_table "rpmdiff_result_details", :primary_key => "result_detail_id", :force => true do |t|
    t.string "subpackage", :limit => 1000
    t.integer "score", :null => false
    t.text "content", :null => false
    t.integer "result_id", :null => false
    t.index ["result_id"], :name => "result_id"
    t.index ["score"], :name => "score"
    t.foreign_key ["result_id"], "rpmdiff_results", ["result_id"], :on_update => :restrict, :on_delete => :restrict, :name => "rpmdiff_result_details_ibfk_2"
    t.foreign_key ["score"], "rpmdiff_scores", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "rpmdiff_result_details_ibfk_1"
  end

  create_table "rpmdiff_autowaive_rule", :primary_key => "autowaive_rule_id", :force => true do |t|
    t.boolean "active"
    t.string "package_name", :limit => 256, :null => false
    t.string "package_version", :limit => 256
    t.integer "test_id", :null => false
    t.string "subpackage", :limit => 256
    t.string "string_expression", :limit => 1000
    t.string "reason", :limit => 1000
    t.integer "created_by"
    t.integer "approved_by"
    t.datetime "created_at"
    t.datetime "approved_at"
    t.integer "score", :null => false
    t.text "content_pattern", :null => false
    t.integer "created_from_rpmdiff_result_detail_id"
    t.index ["approved_by"], :name => "index_rpmdiff_autowaive_rule_on_approved_by"
    t.index ["created_by"], :name => "index_rpmdiff_autowaive_rule_on_created_by"
    t.index ["created_from_rpmdiff_result_detail_id"], :name => "created_from_rpmdiff_result_detail_id"
    t.index ["score"], :name => "index_rpmdiff_autowaive_rule_on_score"
    t.index ["test_id"], :name => "test_id"
    t.foreign_key ["approved_by"], "users", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "rpmdiff_autowaive_rule_ibfk_3"
    t.foreign_key ["created_by"], "users", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "rpmdiff_autowaive_rule_ibfk_2"
    t.foreign_key ["created_from_rpmdiff_result_detail_id"], "rpmdiff_result_details", ["result_detail_id"], :on_update => :restrict, :on_delete => :restrict, :name => "rpmdiff_autowaive_rule_ibfk_5"
    t.foreign_key ["score"], "rpmdiff_scores", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "rpmdiff_autowaive_rule_ibfk_4"
    t.foreign_key ["test_id"], "rpmdiff_tests", ["test_id"], :on_update => :restrict, :on_delete => :cascade, :name => "rpmdiff_autowaive_rule_ibfk_1"
  end

  create_table "rpmdiff_autowaive_product_versions", :force => true do |t|
    t.integer "product_version_id", :null => false
    t.integer "autowaive_rule_id", :null => false
    t.index ["autowaive_rule_id"], :name => "autowaive_rule_id"
    t.index ["product_version_id"], :name => "product_version_id"
    t.foreign_key ["autowaive_rule_id"], "rpmdiff_autowaive_rule", ["autowaive_rule_id"], :on_update => :restrict, :on_delete => :restrict, :name => "rpmdiff_autowaive_product_versions_ibfk_2"
    t.foreign_key ["product_version_id"], "product_versions", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "rpmdiff_autowaive_product_versions_ibfk_1"
  end

  create_table "rpmdiff_autowaived_result_details", :force => true do |t|
    t.integer "result_detail_id", :null => false
    t.integer "autowaive_rule_id", :null => false
    t.datetime "created_at", :null => false
    t.index ["autowaive_rule_id"], :name => "index_rpmdiff_autowaived_result_details_on_autowaive_rule_id"
    t.index ["result_detail_id", "autowaive_rule_id"], :name => "uniq_idx_autowaived_result_details", :unique => true
    t.index ["result_detail_id"], :name => "index_rpmdiff_autowaived_result_details_on_result_detail_id"
    t.foreign_key ["autowaive_rule_id"], "rpmdiff_autowaive_rule", ["autowaive_rule_id"], :on_update => :restrict, :on_delete => :restrict, :name => "rpmdiff_autowaived_result_details_ibfk_2"
    t.foreign_key ["result_detail_id"], "rpmdiff_result_details", ["result_detail_id"], :on_update => :restrict, :on_delete => :restrict, :name => "rpmdiff_autowaived_result_details_ibfk_1"
  end

  create_table "rpmdiff_waivers", :primary_key => "waiver_id", :force => true do |t|
    t.integer "result_id", :null => false
    t.text "description", :null => false
    t.datetime "waive_date", :null => false
    t.integer "old_result", :null => false
    t.integer "run_id", :null => false
    t.integer "test_id", :null => false
    t.integer "package_id", :null => false
    t.integer "user_id", :null => false
    t.boolean "acked", :default => false, :null => false
    t.integer "acked_by"
    t.string "ack_description"
    t.index ["old_result"], :name => "rpmdiff_waivers_result_search_idx"
    t.index ["package_id", "test_id"], :name => "package_waiver_idx"
    t.index ["result_id", "waiver_id"], :name => "rpmdiff_waivers_idx"
    t.index ["run_id"], :name => "run_id"
    t.index ["test_id"], :name => "test_id"
    t.index ["user_id"], :name => "user_id"
    t.foreign_key ["package_id"], "packages", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "rpmdiff_waivers_ibfk_3"
    t.foreign_key ["result_id"], "rpmdiff_results", ["result_id"], :on_update => :restrict, :on_delete => :cascade, :name => "waivers_fk_result_id"
    t.foreign_key ["run_id"], "rpmdiff_runs", ["run_id"], :on_update => :restrict, :on_delete => :restrict, :name => "rpmdiff_waivers_ibfk_1"
    t.foreign_key ["test_id"], "rpmdiff_tests", ["test_id"], :on_update => :restrict, :on_delete => :restrict, :name => "rpmdiff_waivers_ibfk_2"
    t.foreign_key ["user_id"], "users", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "rpmdiff_waivers_ibfk_4"
  end

  create_table "sessions", :force => true do |t|
    t.string "session_id"
    t.text "data", :limit => 16777215
    t.datetime "updated_at"
  end

  create_table "settings", :force => true do |t|
    t.string "var", :null => false
    t.text "value"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["var"], :name => "index_settings_on_var"
  end

  create_table "sha256sums", :force => true do |t|
    t.integer "brew_file_id", :null => false
    t.integer "sig_key_id", :null => false
    t.datetime "created_at", :null => false
    t.string "value", :null => false
    t.index ["brew_file_id"], :name => "sha256sums_brew_file_fk"
    t.index ["sig_key_id", "brew_file_id"], :name => "sha256sum_sig_rpm_idx"
    t.index ["value"], :name => "sha256sums_value_idx"
    t.foreign_key ["brew_file_id"], "brew_files", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "sha256sums_brew_file_fk"
    t.foreign_key ["sig_key_id"], "sig_keys", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "sha256sums_ibfk_1"
  end

  create_table "srpm_cdn_paths", :force => true do |t|
    t.integer "variant_id", :null => false
    t.string "path", :null => false
    t.string "path_type", :null => false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["variant_id"], :name => "variant_id"
    t.foreign_key ["variant_id"], "errata_versions", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "srpm_cdn_paths_ibfk_1"
  end

  create_table "state_machine_rule_sets", :force => true do |t|
    t.string "name", :null => false
    t.string "description", :null => false
    t.string "test_requirements", :limit => 3200, :null => false
    t.boolean "is_locked", :default => false, :null => false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "state_transitions", :force => true do |t|
    t.string "from", :null => false
    t.string "to", :null => false
    t.string "roles", :null => false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean "is_user_selectable", :default => true, :null => false
    t.index ["from", "to"], :name => "index_state_transitions_on_from_and_to"
  end

  create_table "text_diffs", :force => true do |t|
    t.integer "errata_id", :null => false
    t.integer "user_id", :null => false
    t.datetime "created_at", :null => false
    t.integer "old_id"
    t.text "diff", :null => false
    t.index ["errata_id", "created_at"], :name => "text_diff_idx"
    t.index ["old_id"], :name => "text_diff_old_id_idx"
    t.index ["user_id"], :name => "user_id"
    t.foreign_key ["errata_id"], "errata_main", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "text_diffs_ibfk_1"
    t.foreign_key ["user_id"], "users", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "text_diffs_ibfk_2"
  end

  create_table "text_only_channel_lists", :force => true do |t|
    t.integer "errata_id", :null => false
    t.text "channel_list", :null => false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text "cdn_repo_list", :null => false
    t.index ["errata_id"], :name => "errata_id"
    t.foreign_key ["errata_id"], "errata_main", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "text_only_channel_lists_ibfk_1"
  end

  create_table "tps_stream_types", :force => true do |t|
    t.string "name", :null => false
  end

  create_table "tps_variants", :force => true do |t|
    t.string "name", :null => false
  end

  create_table "tps_streams", :force => true do |t|
    t.string "name", :null => false
    t.boolean "active", :null => false
    t.integer "parent_id"
    t.integer "tps_stream_type_id", :null => false
    t.integer "tps_variant_id", :null => false
    t.index ["parent_id"], :name => "index_tps_streams_on_parent_id"
    t.index ["tps_stream_type_id"], :name => "index_tps_streams_on_tps_stream_type_id"
    t.index ["tps_variant_id"], :name => "index_tps_streams_on_tps_variant_id"
    t.foreign_key ["tps_stream_type_id"], "tps_stream_types", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "tps_streams_ibfk_1"
    t.foreign_key ["tps_variant_id"], "tps_variants", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "tps_streams_ibfk_2"
  end

  create_table "tpsstates", :force => true do |t|
    t.string "state", :null => false
    t.index ["state", "id"], :name => "tpsstates_state_idx"
  end

  create_table "tpsruns", :primary_key => "run_id", :force => true do |t|
    t.integer "errata_id", :null => false
    t.integer "state_id", :null => false
    t.datetime "started"
    t.datetime "finished"
    t.integer "current", :default => 1, :null => false
    t.index ["errata_id"], :name => "errata_id"
    t.index ["state_id"], :name => "state_id"
    t.foreign_key ["errata_id"], "errata_main", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "tpsruns_ibfk_1"
    t.foreign_key ["state_id"], "tpsstates", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "tpsruns_ibfk_2"
  end

  add_foreign_key "errata_main", ["current_tps_run"], "tpsruns", ["run_id"], :on_update => :restrict, :on_delete => :restrict, :name => "errata_main_ibfk_1"

  create_table "tpsjobs", :primary_key => "job_id", :force => true do |t|
    t.integer "run_id", :null => false
    t.integer "arch_id", :null => false
    t.integer "version_id", :null => false
    t.string "host", :null => false
    t.integer "state_id", :null => false
    t.datetime "started"
    t.datetime "finished"
    t.string "link", :default => "", :null => false
    t.string "link_text", :default => "", :null => false
    t.integer "in_queue", :default => 0, :null => false
    t.integer "errata_id", :default => 0, :null => false
    t.boolean "channel_was_set", :default => false, :null => false
    t.integer "channel_id"
    t.integer "cdn_repo_id"
    t.string "type", :null => false
    t.index ["arch_id"], :name => "arch_id"
    t.index ["channel_id"], :name => "channel_id"
    t.index ["errata_id"], :name => "errata_id"
    t.index ["run_id"], :name => "run_id"
    t.index ["state_id"], :name => "state_id"
    t.index ["version_id", "arch_id"], :name => "tpsjobs_relarch_idx"
    t.index ["version_id"], :name => "version_id"
    t.foreign_key ["arch_id"], "errata_arches", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "tpsjobs_ibfk_2"
    t.foreign_key ["channel_id"], "channels", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "tpsjobs_ibfk_9"
    t.foreign_key ["errata_id"], "errata_main", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "tpsjobs_ibfk_5"
    t.foreign_key ["run_id"], "tpsruns", ["run_id"], :on_update => :restrict, :on_delete => :restrict, :name => "tpsjobs_ibfk_1"
    t.foreign_key ["state_id"], "tpsstates", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "tpsjobs_ibfk_4"
    t.foreign_key ["version_id"], "errata_versions", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "tpsjobs_ibfk_3"
  end

end
