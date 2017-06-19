# This image is merely the official rhel7 image with some brew repos added
FROM docker-registry.usersys.redhat.com/redhat/rhel7.0:latest

RUN rm -f /etc/yum.repos.d/rhel7.repo
ADD rhel7.repo /etc/yum.repos.d/rhel7.repo
