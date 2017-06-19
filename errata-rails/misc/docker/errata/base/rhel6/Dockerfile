FROM registry.access.redhat.com/rhel6:latest

ADD repos/*.repo /etc/yum.repos.d/
RUN yum clean all && yum repolist && yum upgrade -y && yum clean all
