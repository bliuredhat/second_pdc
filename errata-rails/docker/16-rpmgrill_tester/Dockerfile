FROM docker-registry.usersys.redhat.com/errata_tool/rhel6:latest

# some deps are not otherwise available
RUN yum -y install http://mirror.rackcentral.com.au/epel/6/i386/epel-release-6-8.noarch.rpm && yum clean all

RUN yum -y install \
  clamav \
  desktop-file-utils \
  elfutils \
  elfutils-devel \
  gcc \
  perl-Algorithm-Diff \
  perl-CGI \
  perl-Clone \
  perl-Crypt-SSLeay \
  perl-Devel-Cover \
  perl-Digest-SHA \
  perl-File-LibMagic \
  perl-File-Slurp \
  perl-File-Which \
  perl-IPC-Run \
  perl-JSON-XS \
  perl-Module-Build \
  perl-Net-DNS \
  perl-Perl-Critic \
  perl-Sort-Versions \
  perl-Task-Perl-Critic \
  perl-Test-Deep \
  perl-Test-Differences \
  perl-Test-LongString \
  perl-Test-Perl-Critic \
  perl-Test-Simple \
  perl-Time-Piece \
  perl-Time-modules \
  perl-XML-Simple \
  perl-YAML \
  perl-YAML-Syck \
  perl-libwww-perl \
  && yum clean all

RUN useradd -u 1000 tester

VOLUME ["/workspace"]
RUN chown tester:tester /workspace
WORKDIR /workspace

ADD run-test /run-test
ENTRYPOINT ["/run-test"]
