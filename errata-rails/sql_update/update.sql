alter table user_group_map rename column group_id to user_group_id;
alter table errata_comment rename column comment_when to created_at;

create table bug_references (
id integer not null primary key
);

insert into bug_references select distinct bug_id from errata_bug_map;
alter table errata_content rename column last_updated to updated_at;

alter table errata_main add column status_updated_at timestamp with time zone;

update errata_main set status_updated_at = (select awhen from (
select m.id as errata_id, max(a.activity_when) as awhen from errata_main m, errata_activity a
 where m.id = a.id and
 a.what='status' and
 a.added = m.status
group by m.id) as foo
where id = errata_id);
update errata_main set status_updated_at = issue_date where status_updated_at is null;


alter table errata_main alter column status_updated_at set default now();
alter table errata_main alter column status_updated_at set not null;
