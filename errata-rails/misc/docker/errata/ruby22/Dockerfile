FROM errata_dev:latest
USER root

COPY errata-rails-rhel-6.repo /etc/yum.repos.d/

RUN yum -y  install \
    --disablerepo rcm-tools-rhel-6-server-rpms  \
    --disablerepo rcm-tools-rhel-6-server-optional-rpms  \
      cmake \
      gcc-c++ \
      libstdc++-devel \
      libyaml-devel \
      qpid-cpp-client-devel \
      qpid-proton-c-devel \
      qpid-tools \
      rh-ruby22 \
      rh-ruby22-build \
      rh-ruby22-ruby-devel \
      rh-ruby22-rubygem-bundler \
      rh-ruby22-rubygems-devel \
      scl-utils \
      scl-utils-build \
      wget \
  && yum clean all

# Add phantomjs
ARG phantomjs_version=2.1.1
ARG phantomjs_dir=phantomjs-${phantomjs_version}-linux-x86_64
ARG phantomjs_file=${phantomjs_dir}.tar.bz2

# see: http://phantomjs.org/download.html#checksums
ARG phantomjs_url=https://bitbucket.org/ariya/phantomjs/downloads/${phantomjs_file}
ARG phantomjs_tar=/tmp/${phantomjs_file}
ARG phantomjs_sha256="86dd9a4bf4aee45f1a84c9f61cf1947c1d6dce9b9e8d2a907105da7852460d2f  $phantomjs_tar"

RUN wget -q -O $phantomjs_tar $phantomjs_url && \
    echo "$phantomjs_sha256" > /tmp/checksum  && \
    sha256sum -c /tmp/checksum && \
    tar -xjf $phantomjs_tar -C /tmp && \
    rm -f $phantomjs_tar /tmp/checksum && \
    mv /tmp/$phantomjs_dir /opt/phantomjs && \
    ln -s /opt/phantomjs/bin/phantomjs /usr/bin/phantomjs


# make scl ruby22 the default
# copied from /opt/rh/rh-ruby22/enable
ENV PATH=/opt/rh/rh-ruby22/root/usr/bin${PATH:+:${PATH}}
ENV LD_LIBRARY_PATH=/opt/rh/rh-ruby22/root/usr/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}
ENV MANPATH=/opt/rh/rh-ruby22/root/usr/share/man:$MANPATH
ENV PKG_CONFIG_PATH=/opt/rh/rh-ruby22/root/usr/lib64/pkgconfig${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}
ENV XDG_DATA_DIRS=/opt/rh/rh-ruby22/root/usr/share${XDG_DATA_DIRS:+:${XDG_DATA_DIRS}}

# So we can load some useful aliases
ADD dot_bashrc /home/dev/.bashrc

USER dev
WORKDIR /code
CMD bash
