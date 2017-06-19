#!/bin/sh
RAKE=/usr/bin/rake

MAILX=/bin/mailx
RECIPIENT=sbaird@redhat.com,jblazek@redhat.com,mikeb@redhat.com
HOSTNAME=`/bin/hostname`
SUBJECT="$HOSTNAME: Autowaive ppc64le and aarch64 rpmdiff results cron job"

case $HOSTNAME in
  errata.devel.redhat.com)
    RAILS_ENV=production
    APP_DIR=/var/www/errata_rails
    ;;
  *.usersys.redhat.com)
    RAILS_ENV=development
    APP_DIR=.
    ;;
  *)
    RAILS_ENV=staging
    APP_DIR=/var/www/errata_rails
    ;;
esac

QUIET=0
REALLY=1

cd $APP_DIR && $RAKE RAILS_ENV=$RAILS_ENV QUIET=$QUIET REALLY=$REALLY debug:rpmdiff:autowaive_arch_results | $MAILX -s "$SUBJECT" $RECIPIENT
