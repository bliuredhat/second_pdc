#
# Defines some useful bash shortcuts for use on
# devel, staging and production Errata Tool servers.
#
# Commands
# --------
#  $ etsandbox  # Start rails console as erratatool user
#                 in --sandbox mode.
#
#  $ etconsole  # Start rails console as erratatool user.
#
#  $ etshell    # Start a bash shell in rails root dir as user
#               # erratatool and with a suitable RAILS_ENV set.
#
#  $ etrestart  # Restart rails by touching tmp/restart.txt
#
#  $ ettailhttp # Tail -f the apache access log
#
# Usage
# -----
#  $ source /var/www/errata_rails/script/bash_utils.sh
#
ET_ROOT_DIR='/var/www/errata_rails'
ET_USER='erratatool'
ET_PROD_HOST='errata-web-01.host.prod.eng.bos.redhat.com'
ET_CURRENT_HOST=`hostname`

_do_et_cmd() {
  if [ $ET_CURRENT_HOST = $ET_PROD_HOST ]; then
    echo ''
    echo '******************************************'
    echo '*** !!! WARNING: PRODUCTION SYSTEM !!! ***'
    echo '******************************************'
    echo ''
    RAILS_ENV=production
  else
    RAILS_ENV=staging
  fi

  echo HOST: $ET_CURRENT_HOST
  echo RAILS_ENV: $RAILS_ENV

  sudo -u $ET_USER -i bash -c "cd $ET_ROOT_DIR; RAILS_ENV=$RAILS_ENV $1"
}

etshell() {
  _do_et_cmd 'bash'
}

etrestart() {
  _do_et_cmd 'touch tmp/restart.txt'
}

etsandbox() {
  _do_et_cmd 'bundle exec rails console --sandbox'
}

etconsole() {
  _do_et_cmd 'bundle exec rails console'
}

ettailhttp() {
  sudo tail -f /var/log/httpd24/ssl_access_log | grep -E -v '\.png|\.jpg|\.gif|\.css|favico\.ico'
}
