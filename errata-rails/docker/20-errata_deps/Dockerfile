FROM docker-registry.usersys.redhat.com/errata_tool/rails32:latest
ADD etc /etc
# Most of these should be dependencies of the errata-rails rpm.
# They're included in this image so that subsequent images don't
# waste time and space reinstalling them on rebuilds.
RUN yum -y install \
 httpd \
 nfs-utils \
 ruby \
 rubygems \
 vim-enhanced \
 boost-filesystem \
 boost-program-options \
 boost-system \
 cyrus-sasl-gssapi \
 finger \
 hunspell \
 hunspell-en \
 krb5-workstation \
 qpid-cpp-client \
 qpid-cpp-client-ssl \
 qpid-qmf \
 ruby-qpid \
 ruby-qpid-qmf \
 koji && \
 yum -y upgrade && \
 yum clean all
