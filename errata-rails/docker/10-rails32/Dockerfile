FROM docker-registry.usersys.redhat.com/errata_tool/rhel6:latest
RUN cd /etc/yum.repos.d && \
  curl --fail -L http://file.bos.redhat.com/~jorris/repo/rhel6-errata-rails32.repo -o rhel6-errata-rails32.repo
