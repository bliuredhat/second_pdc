#!/bin/sh
#
# See also the Teiid User Guide at https://docs.engineering.redhat.com/x/E4gEAQ
# (Port 5432 will prompt for a password, 5433 will use Kerberos)
#

[ -z "$TEIID_HOST" ] && TEIID_HOST=prod
[ -z "$TEIID_PORT" ] && TEIID_PORT=5433
[ -z "$TEIID_USER" ] && TEIID_USER=$USER
[ -z "$TEIID_VDB" ] && TEIID_VDB=public

# Uncomment this for comma separated output
#[ -z "$PSQL_OPTS" ] && PSQL_OPTS='-A -t -F,'

[ "$TEIID_HOST" = "prod" ] && TEIID_HOST=virtualdb.engineering.redhat.com
[ "$TEIID_HOST" = "stage" ] && TEIID_HOST=teiid-stage.app.eng.bne.redhat.com
[ "$TEIID_HOST" = "devel" ] && TEIID_HOST=teiid-devel.app.eng.bne.redhat.com

PSQL=/usr/bin/psql
PSQL_CMD="$PSQL -h $TEIID_HOST -p $TEIID_PORT -U $TEIID_USER -d $TEIID_VDB $PSQL_OPTS"

SQL_FILE=$1

if [ -n "$SQL_FILE" ]; then
  # Assume sql is in the file
  exec $PSQL_CMD < $SQL_FILE

else
  # Assume sql is on STDIN (or you want to start an interactive session)
  exec $PSQL_CMD

fi
