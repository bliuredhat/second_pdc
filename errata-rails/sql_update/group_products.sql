-- 17 | RHEL2.1-MAINT |
update errata_groups set product_version_id = 1 where id = 17;

-- 69 | RHEL3-Maint   |
update errata_groups set product_version_id = 2 where id = 69;

-- 65 | FAST4.7
-- 55 | FAST4.6       |
update errata_groups set product_version_id = 3 where id in (65,55);

-- 64 | FAST5.2
update errata_groups set product_version_id = 16 where id = 64;

-- 77 | RHDS-8        |
-- 76 | RHDS7.1-SP4   |
update errata_groups set product_id = 29 where id in (77,76);


-- 53 | RHGFS3-QU9    |
update errata_groups set product_version_id = 10 where id = 53;

-- 24 | RHAPS-V2U1    |
update errata_groups set product_version_id = 7 where id = 24;

-- 59 | RHAS-V1       |
update errata_groups set product_version_id = 12 where id = 59;

update errata_groups set product_id = (select product_id from product_versions where id = product_version_id) where product_version_id is not null;
