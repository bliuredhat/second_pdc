FROM docker-registry.usersys.redhat.com/errata_tool/rhel6:latest
ADD etc /etc
RUN yum -y install mysql-server && \
  yum clean all && \
  /etc/init.d/mysqld start && \
  mysql -e "CREATE USER 'root' IDENTIFIED BY 'oW65l7rQK_aw'; GRANT ALL ON *.* TO 'root'"
EXPOSE 3306
CMD ["/bin/sh", "-c", "/etc/init.d/mysqld start && exec tail --follow=name /var/log/mysqld.log"]
