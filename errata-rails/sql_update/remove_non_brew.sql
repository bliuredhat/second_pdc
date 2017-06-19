
update errata_main set is_brew = 1 where id = 4260;

create index errata_released_package_idx on released_packages(errata_id);


delete from rpmdiff_results where run_id in (select run_id from rpmdiff_runs where errata_file_id in (select id from errata_files where errata_id in ( select id from errata_main where is_brew = 0)));

delete from rpmdiff_runs where errata_file_id in (select id from errata_files where errata_id in ( select id from errata_main where is_brew = 0));


delete from errata_files where errata_id in ( select id from errata_main where is_brew = 0);

delete from tpsjobs where run_id in (select run_id from tpsruns where errata_id in (select id from errata_main where is_brew = 0));

update errata_main set current_tps_run = null where is_brew = 0;

delete from tpsruns where errata_id in (select id from errata_main where is_brew = 0);


 delete from errata_content where errata_id in (select id from errata_main where is_brew = 0);

delete from errata_bug_map where errata_id in (select id from errata_main where is_brew = 0);

delete from comments where errata_id in (select id from errata_main where is_brew = 0);

delete from errata_activities where errata_id in (select id from errata_main where is_brew = 0);

delete from carbon_copies where errata_id in (select id from errata_main where is_brew = 0);

delete from rpmdiff_results where run_id in (select run_id from rpmdiff_runs where errata_id in (select id from errata_main where is_brew = 0));

delete from rpmdiff_runs where errata_id in (select id from errata_main where is_brew = 0);

delete from errata_main where is_brew = 0;

delete from bugs where id not in (select bug_id from errata_bug_map);


delete from rhn_channels where product_version_id in
(select id from product_versions where product_id in (select id from errata_products where isactive = 0));

delete from errata_versions where product_id in (select id from errata_products where isactive = 0);

delete from product_versions where product_id in (select id from errata_products where isactive = 0);

delete from errata_products where isactive = 0;

delete from errata_groups where id not in (select group_id from errata_main) ;

