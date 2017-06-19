FROM docker-registry.usersys.redhat.com/errata_tool/rhel6:latest

# Update selinux first to prevent the following error
# Installing : mock-1.2.10-1.el6.noarch  33/40Error unpacking rpm package mock-1.2.10-1.el6.noarch
RUN yum update -y libselinux && yum clean all

# Some deps are not otherwise available (e.g. mock)
RUN yum -y install https://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm && yum clean all

RUN yum -y -t install \
  mock \
  koji \
  rpm-build \
  && yum clean all

RUN useradd -u 1000 tester
RUN usermod -a -G mock tester

ENV WORKSPACE /workspace
ENV CONFIG_DIR $WORKSPACE/mockconfig

RUN mkdir -p $WORKSPACE && chown tester:tester $WORKSPACE
WORKDIR $WORKSPACE

ADD mock-default.cfg /mock-default.cfg
ADD run-test /run-test
USER tester
ENTRYPOINT ["/run-test"]
