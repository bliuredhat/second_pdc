FROM docker-registry.usersys.redhat.com/errata_tool/mysqld:latest
ADD errata.sql.gz /tmp/errata.sql.gz

RUN /etc/init.d/mysqld start \
  && mysql -e 'CREATE DATABASE errata' \
  && zcat /tmp/errata.sql.gz | sed -e 's|^) ENGINE=InnoDB|\0 ROW_FORMAT=COMPRESSED KEY_BLOCK_SIZE=8|' | mysql -v --database=errata | grep -e '^CREATE TABLE' \
  && rm -f /tmp/errata.sql.gz

EXPOSE 3306
CMD ["/bin/sh", "-c", "/etc/init.d/mysqld start && exec tail --follow=name /var/log/mysqld.log"]
