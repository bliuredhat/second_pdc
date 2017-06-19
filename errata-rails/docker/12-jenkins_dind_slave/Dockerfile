FROM docker-registry.usersys.redhat.com/errata_tool/rhel7:latest

ADD cdn-internal.repo /etc/yum.repos.d/cdn-internal.repo

RUN yum -y upgrade && yum clean all

# Set up real systemd, running just jenkins-slave, docker and journald.
RUN yum -y swap -- remove fakesystemd -- install systemd systemd-libs && yum clean all

RUN yum -y install \
  java-1.7.0-openjdk-headless \
  git \
  docker \
  curl \
  e2fsprogs \
  iptables \
  && yum clean all

# These are symlinks to support entitlements within docker containers.
# These break things for us since we don't use entitlements.
RUN rm -rfv /usr/share/rhel/secrets/*

ADD RH_IT_Chain.crt /tmp/rh_it_chain.crt
RUN cat /tmp/rh_it_chain.crt >> /etc/pki/tls/certs/ca-bundle.crt
RUN yes | keytool -importcert -trustcacerts -alias "Red Hat IS CA" -file /tmp/rh_it_chain.crt -keystore /etc/pki/java/cacerts -storepass changeit

ADD Eng-CA.crt /tmp/engca.crt
RUN cat /tmp/engca.crt >> /etc/pki/tls/certs/ca-bundle.crt
RUN yes | keytool -importcert -trustcacerts -alias "Eng-Ops CA" -file /tmp/engca.crt -keystore /etc/pki/java/cacerts -storepass changeit

# copied from http://developerblog.redhat.com/2014/05/05/running-systemd-within-docker-container/
RUN (cd /lib/systemd/system/sysinit.target.wants/; for i in *; do [ $i == systemd-tmpfiles-setup.service ] || rm -f $i; done); \
  rm -f /lib/systemd/system/multi-user.target.wants/*;\
  rm -f /etc/systemd/system/*.wants/*;\
  rm -f /lib/systemd/system/local-fs.target.wants/*; \
  rm -f /lib/systemd/system/sockets.target.wants/*udev*; \
  rm -f /lib/systemd/system/sockets.target.wants/*initctl*; \
  rm -f /lib/systemd/system/basic.target.wants/*;\
  rm -f /lib/systemd/system/anaconda.target.wants/*

ADD jenkins-slave.service /etc/systemd/system/jenkins-slave.service
ADD mkloops.service /etc/systemd/system/mkloops.service

RUN mkdir -p /usr/lib/systemd/system/docker.service.wants && \
  cd /usr/lib/systemd/system/docker.service.wants && \
  ln -sf /etc/systemd/system/mkloops.service .

# The intent here is to make journal output accessible via "docker logs".
# Note that it only works if the container is run with -t (psuedo-tty).
RUN echo 'ForwardToConsole=yes' >> /etc/systemd/journald.conf

# Allow non-SSL internal registry to be used
ADD sysconfig_docker /etc/sysconfig/docker

ADD mkloops /mkloops
ADD run-slave /run-slave
ADD run-container /run-container

# Add the Jenkins user to the docker group which we'll have to create manually
# in order to allow him to run containers with root privileges
RUN useradd -u 1000 jenkins
RUN groupadd docker
RUN gpasswd -a jenkins docker

RUN git config --system user.email nobody@redhat.com
RUN git config --system user.name "Jenkins Slave"

ENV container docker
VOLUME ["/sys/fs/cgroup", "/var/lib/docker", "/var/lib/jenkins", "/run"]
ENTRYPOINT ["/run-container"]
