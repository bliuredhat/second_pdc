FROM docker-registry.usersys.redhat.com/errata_tool/errata_deps:latest
RUN yum install -y mod_passenger mod_ssl && yum clean all
ADD etc /etc
