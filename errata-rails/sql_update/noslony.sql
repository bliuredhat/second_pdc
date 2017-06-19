drop table errata_xml;
drop table errata_tests_results;
drop table errata_class;
drop table errata_latest;
drop table errata_meta;
drop table errata_meta_map;
drop table errata_sanity_hosts;
drop table errata_sanity;
drop table errata_tests_hosts;
drop table rpmdiff_results_cpy;
drop table errata_attachments;
drop table errata_activity;
drop table errata_comment;
drop table errata_cc;
drop table tpsfiles_stacks;
drop table tps_stacks_releases;
drop table tpsfiles_stacks;

drop table tpsjobs_nonerrata;
drop table tpsruns_nonerrata;
drop table tpsfiles;
drop table errata_rel_arch_map;
drop table errata_resolution;
drop table errata_status;
drop table errata_tests;
drop table errata_type;


drop table errata_groups_map;

alter table errata_activity drop column "_Slony-I_errata_cluster_rowID";
alter table errata_comment drop column "_Slony-I_errata_cluster_rowID";
alter table errata_bug_map drop column "_Slony-I_errata_cluster_rowID";





 drop trigger _errata_cluster_logtrigger_42 on errata_activity;
 drop trigger _errata_cluster_logtrigger_43 on errata_arches;
 drop trigger _errata_cluster_logtrigger_62 on errata_attachments;
 drop trigger _errata_cluster_logtrigger_8  on errata_brew_mappings;
 drop trigger _errata_cluster_logtrigger_53 on errata_bug_map;
 drop trigger _errata_cluster_logtrigger_55 on errata_cc;
 drop trigger _errata_cluster_logtrigger_56 on errata_comment;
 drop trigger _errata_cluster_logtrigger_63 on errata_content;
 drop trigger _errata_cluster_logtrigger_9  on errata_file_signatures;
 drop trigger _errata_cluster_logtrigger_10 on errata_files;
 drop trigger _errata_cluster_logtrigger_11 on errata_groups;
 drop trigger _errata_cluster_logtrigger_59 on errata_groups_map;
 drop trigger _errata_cluster_logtrigger_12 on errata_key_map;
 drop trigger _errata_cluster_logtrigger_57 on errata_main;
 drop trigger _errata_cluster_logtrigger_45 on errata_package_arch_exclusions;
 drop trigger _errata_cluster_logtrigger_13 on errata_packages;
 drop trigger _errata_cluster_logtrigger_14 on errata_priority;
 drop trigger _errata_cluster_logtrigger_54 on errata_products;
 drop trigger _errata_cluster_logtrigger_15 on errata_rel_arch_map;
 drop trigger _errata_cluster_logtrigger_16 on errata_resolution;
 drop trigger _errata_cluster_logtrigger_17 on errata_severity;
 drop trigger _errata_cluster_logtrigger_18 on errata_status;
 drop trigger _errata_cluster_logtrigger_64 on errata_tests;
 drop trigger _errata_cluster_logtrigger_19 on errata_type;
 drop trigger _errata_cluster_logtrigger_20 on errata_types;
 drop trigger _errata_cluster_logtrigger_61 on errata_versions;
 drop trigger _errata_cluster_logtrigger_21 on product_versions;
 drop trigger _errata_cluster_logtrigger_22 on released_packages;
 drop trigger _errata_cluster_logtrigger_23 on rhel_releases;
 drop trigger _errata_cluster_logtrigger_24 on rhn_channels;
 drop trigger _errata_cluster_logtrigger_25 on rpmdiff_results;
 drop trigger _errata_cluster_logtrigger_26 on rpmdiff_runs;
 drop trigger _errata_cluster_logtrigger_27 on rpmdiff_scores;
 drop trigger _errata_cluster_logtrigger_28 on rpmdiff_tests;
 drop trigger _errata_cluster_logtrigger_29 on rpmdiff_waivers;
 drop trigger _errata_cluster_logtrigger_30 on sig_keys;
 drop trigger _errata_cluster_logtrigger_31 on tps_stacks_releases;
 drop trigger _errata_cluster_logtrigger_32 on tps_systems;
 drop trigger _errata_cluster_logtrigger_33 on tpsfiles;
 drop trigger _errata_cluster_logtrigger_34 on tpsfiles_stacks;
 drop trigger _errata_cluster_logtrigger_35 on tpsjobs;
 drop trigger _errata_cluster_logtrigger_36 on tpsjobs_nonerrata;
 drop trigger _errata_cluster_logtrigger_37 on tpsruns;
 drop trigger _errata_cluster_logtrigger_38 on tpsruns_nonerrata;
 drop trigger _errata_cluster_logtrigger_39 on tpsstates;
 drop trigger _errata_cluster_logtrigger_44 on user_group_map;
 drop trigger _errata_cluster_logtrigger_40 on user_groups;
 drop trigger _errata_cluster_logtrigger_41 on users;


drop table sl_archive_counter;
drop table sl_config_lock    ;
drop table sl_confirm        ;
drop table sl_listen         ;
drop table sl_path           ;
drop table sl_node           ;
drop table sl_nodelock       ;

drop table sl_registry       ;
drop table sl_seqlog         ;
drop table sl_sequence       ;
drop table sl_subscribe      ;
drop table sl_table          ;
drop table sl_trigger        ;


drop sequence sl_action_seq   ;
drop sequence sl_event_seq                      ;
drop sequence sl_local_node_id                  ;
drop sequence sl_log_status                     ;
drop sequence sl_rowid_seq                      ;
drop table errata_package_arch_exclusions;
drop table errata_key_map;
drop table errata_file_signatures;
drop table bug_references;
