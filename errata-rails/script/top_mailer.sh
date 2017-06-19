#!/bin/sh
#
# Run this via crontab once per hour to monitor memory usage
# patterns. It will send an email containing some useful top output.
#
TOP=/usr/bin/top
HEAD=/usr/bin/head
MAILX=/bin/mailx
SED=/bin/sed
RECIPIENT=errata-owner@redhat.com
LINECOUNT=60
SUBJECT='ET: top'
COLUMNS=400

$TOP -b |
  $SED 's/ *$//' |
  $HEAD -$LINECOUNT |
  $MAILX -s "$SUBJECT" $RECIPIENT

# Note:
# The erratatool user's .toprc file (/usr/local/home/erratatool)
# is important here because it specifies the sort order and the
# show command options.
#
# It's easy to create it from scratch as follows:
# - Become erratatool with sudo su
# - Remove existing ~/.toprc file to start from a known state
# - Run top
# - Press M to sort by memory usage
# - Press c to show the command for each process
# - Press W to write new .toprc file
# - Press q to quit top
#
# Suggested crontab content:
## Sends an email once per hour to help monitor Errata Tool memory usage
## -sbaird, 26-Feb-2014, requested by jmcdonal.
#20 * * * * /var/www/errata_rails/script/top_mailer.sh
