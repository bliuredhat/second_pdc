alter table errata_packages rename to packages;
alter table errata_groups rename to releases;

create table release_components (
  id serial not null primary key,
  package_id integer not null references packages(id),
  release_id integer not null references releases(id),
  created_at timestamp without time zone not null
);

alter table packages add column devel_owner_id integer references users(id);
alter table packages add column qe_owner_id integer references users(id);

create table bugs_releases (
   release_id integer not null references releases(id),
   bug_id integer not null references bugs(id)
);