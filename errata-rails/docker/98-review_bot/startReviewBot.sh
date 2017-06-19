#!/bin/sh
keyfile="$HOME/.ssh/id_rsa"

if ! test -f $HOME/.ssh/id_rsa; then
  echo "WARNING: ssh private key is not present at $keyfile"
  echo "Connection to gerrit will probably fail."
  echo "Consider using the -v option to \`docker run' to provide a private ssh key."
  echo "For example: -v /secret/id_rsa_for_review_bot:$keyfile"
fi 1>&2

if [ "x$REVIEW_BOT_REALLY" = "x1" ]; then
  EXTRA_ARGS=""
else
  EXTRA_ARGS="--dry-run"
  echo "INFO: review bot will execute in dry-run mode."
  echo "If you really want to post messages back to gerrit, set REVIEW_BOT_REALLY=1 ,"
  echo "e.g. by adding \`-e REVIEW_BOT_REALLY=1' to the \`docker run' command."
fi

set -x
exec \
  $HOME/gerrit_bots/gerrit-review-bot \
  $EXTRA_ARGS \
  --daemon ssh://jenkins-hss@code.engineering.redhat.com:29418/ \
  --projects errata-rails \
