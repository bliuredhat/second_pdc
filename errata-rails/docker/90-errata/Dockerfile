FROM docker-registry.usersys.redhat.com/errata_tool/webapp_cfg:latest

# - Fix annoying sudo defaults requiring to have a terminal
# - remove asset_host setting since the container doesn't know its outward-facing
#   hostname (if any)
RUN groupadd -r errata \
  && yum -y install sudo \
  && sed -r -e 's|^Defaults.*(requiretty\|!validpw)|#\0|' -i /etc/sudoers \
  && cd /tmp \
  && yum -y install http://download.devel.redhat.com/brewroot/packages/errata-rails/3.8/5.0.el6eso/noarch/errata-rails-3.8-5.0.el6eso.noarch.rpm \
  && sed -r -e 's|^ *config.action_controller.asset_host|#\0|' -i /var/www/errata_rails/config/environments/staging.rb \
  && yum clean all

ADD run-errata-in-docker /run-errata-in-docker
ADD set-server-url /set-server-url
ADD config /var/www/errata_rails/config

EXPOSE 443
CMD ["/run-errata-in-docker"]
