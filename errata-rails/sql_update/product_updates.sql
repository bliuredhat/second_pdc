alter table errata_main drop column product;

alter table errata_main add column group_id integer;
 update errata_main set group_id = (select group_id from errata_groups_map where errata_id = id);
 alter table errata_main add constraint group_id_fk foreign key(group_id) references errata_groups(id);
alter table errata_main alter column group_id set not null;


create table rhel_releases (
    id SERIAL not null primary key,
    name varchar not null,
    description varchar
);

insert into rhel_releases (name, description) values ('RHEL-2.1', 'Red Hat Advanced Server 2.1');
insert into rhel_releases (name, description) values ('RHEL-3', 'Red Hat Enterprise Linux 3');
insert into rhel_releases (name, description) values ('RHEL-4', 'Red Hat Enterprise Linux 4');

alter table product_versions add column rhel_release_id integer references rhel_releases(id);

update product_versions set rhel_release_id = 1 where name like 'RHEL-2.1%';
update product_versions set rhel_release_id = 2 where name like 'RHEL-3%';
update product_versions set rhel_release_id = 3 where name like 'RHEL-4%';

alter table errata_versions add column rhel_release_id integer references rhel_releases(id);
update errata_versions set rhel_release_id = 3 where rhel_variant_id in (91,92,93,94);
update errata_versions set rhel_release_id = 2 where rhel_variant_id in (65,66,67,81);
update errata_versions set rhel_release_id = 1 where rhel_variant_id in (43,44,45,46,55);

create table tps_systems (
    id SERIAL not null primary key,
    rhel_release_id integer not null references rhel_releases(id),
    version_id integer not null references errata_versions(id),
    arch_id integer not null references errata_arches(id),
    description varchar
);

-- RHEL4 AS i386
insert into tps_systems (rhel_release_id, version_id, arch_id, description) values (3, 91, 4, 'RHEL4 AS i386');
-- RHEL4 AS ia64
insert into tps_systems (rhel_release_id, version_id, arch_id, description) values (3, 91, 7, 'RHEL4 AS ia64');
-- RHEL4 AS s390
insert into tps_systems (rhel_release_id, version_id, arch_id, description) values (3, 91, 9, 'RHEL4 AS s390');
-- RHEL4 AS s390x
insert into tps_systems (rhel_release_id, version_id, arch_id, description) values (3, 91, 14, 'RHEL4 AS s390x');
-- RHEL4 AS ppc
insert into tps_systems (rhel_release_id, version_id, arch_id, description) values (3, 91, 17, 'RHEL4 AS ppc');
-- RHEL4 AS x86_64
insert into tps_systems (rhel_release_id, version_id, arch_id, description) values (3, 91, 13, 'RHEL4 AS x86_64');

-- RHEL3 AS i386
insert into tps_systems (rhel_release_id, version_id, arch_id, description) values (2, 66, 4, 'RHEL3 AS i386');
-- RHEL3 AS ia64
insert into tps_systems (rhel_release_id, version_id, arch_id, description) values (2, 66, 7, 'RHEL3 AS ia64');
-- RHEL3 AS s390
insert into tps_systems (rhel_release_id, version_id, arch_id, description) values (2, 66, 9, 'RHEL3 AS s390');
-- RHEL3 AS s390x
insert into tps_systems (rhel_release_id, version_id, arch_id, description) values (2, 66, 14, 'RHEL3 AS s390x');
-- RHEL3 AS ppc
insert into tps_systems (rhel_release_id, version_id, arch_id, description) values (2, 66, 17, 'RHEL3 AS ppc');
-- RHEL3 AS x86_64
insert into tps_systems (rhel_release_id, version_id, arch_id, description) values (2, 66, 13, 'RHEL3 AS x86_64');

-- RHEL3 ES i386
insert into tps_systems (rhel_release_id, version_id, arch_id, description) values (2, 67, 4, 'RHEL3 ES i386');
-- RHEL3 ES ia64
insert into tps_systems (rhel_release_id, version_id, arch_id, description) values (2, 67, 7, 'RHEL3 ES ia64');

-- RHEL3 WS x86_64
insert into tps_systems (rhel_release_id, version_id, arch_id, description) values (2, 65, 13, 'RHEL3 WS x86_64');


-- RHEL2.1 AS i386
insert into tps_systems (rhel_release_id, version_id, arch_id, description) values (1, 43, 4, 'RHEL2.1 AS i386');
-- RHEL2.1 AS ia64
insert into tps_systems (rhel_release_id, version_id, arch_id, description) values (1, 43, 7, 'RHEL2.1 AS ia64');

