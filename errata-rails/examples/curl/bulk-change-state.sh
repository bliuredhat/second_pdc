#!/bin/bash
#
# Move RHEL-7.4.0 advisories in QE to NEW_FILES
#
# See https://engineering.redhat.com/rt/Ticket/Display.html?id=438824
#
set -euo pipefail

# This is RHEL-7.4.0
RELEASE_ID=652
STATE=QE
PAGE=1
ET_HOST=errata.devel.redhat.com
TMP_FILE=`mktemp`
COMMENT="Moving back to NEW_FILES for bulk file list reload as requested at RT#438824."

# Set this to nothing to really do it
DRY_RUN_MAYBE="echo DRY RUN"

# Fetch list of advisories
# (Note that we're disregarding pagination here out of laziness. If there
# are more than 250 advisories this will not get them all.)
curl -s -u: --negotiate "https://$ET_HOST/errata" -H "Accept: application/json" -X GET \
  -d "errata_filter[filter_params][show_type_RHBA]=1" \
  -d "errata_filter[filter_params][show_type_RHEA]=1" \
  -d "errata_filter[filter_params][show_type_RHSA]=1" \
  -d "errata_filter[filter_params][show_state_$STATE]=1" \
  -d "errata_filter[filter_params][release][]=$RELEASE_ID" \
  -d "errata_filter[filter_params][output_format]=standard" \
  -d "errata_filter[filter_params][pagination_option]=250" \
  -d "page=$PAGE" \
  > $TMP_FILE

# Take a look first...
jq '.[] | .advisory_name + " " + .status + " " + .release.name + " " + .synopsis' < $TMP_FILE
echo `jq length < $TMP_FILE` advisories found
echo "Page: $PAGE"
echo "NB: Filter result may paginated at 250 advisories per page"
echo Comment: \"$COMMENT\"
echo "About to move these advisories to NEW_FILES with the above comment. Ctrl-C to cancel. Enter to continue."
read

IDS=`jq '.[] | .id' < $TMP_FILE | sort -n`
for id in $IDS; do
  echo Moving $id back to to NEW_FILES...
  $DRY_RUN_MAYBE curl -X POST \
    -u : --negotiate \
    -H "Content-type: application/json" \
    "https://$ET_HOST/api/v1/erratum/$id/change_state" \
    -d "{\"new_state\":\"NEW_FILES\",\"comment\":\"$COMMENT\"}"

  echo ''
  sleep 1 # be kind to ET!
done
