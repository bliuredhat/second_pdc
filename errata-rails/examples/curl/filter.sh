#!/bin/sh
#
# Example showing how to script an adhoc advisory search (instead of using
# manually created predefined filter).
#
# This should not be considered a supported API but maybe it can be used to
# get the data you need.
#
# Notes:
#
# - Unfortunately you need to supply the id for many things rather than the
#   name. You can find the ids for most things in a number of ways. (Ask on
#   errata-dev-list for help if you need it).
#
# - You can specify more than one just by repeating the field such as in the
#   release filter option below
#
# - You can figure out other options by creating the search and copy/pasting
#   the long url
#
# - Using GET with a request body seems to work here even though it's doubtful
#   that it ought to. You could do this more correctly by assembling the same
#   data as url params. This should be fairly easy to do in your favourite
#   scripting language.
#
# - Other filter options similar to release:
#    -d 'errata_filter[filter_params][product][]=' \
#    -d 'errata_filter[filter_params][release][]=' \
#    -d 'errata_filter[filter_params][qe_group][]=' \
#    -d 'errata_filter[filter_params][qe_owner][]=' \
#    -d 'errata_filter[filter_params][devel_group][]=' \
#    -d 'errata_filter[filter_params][reporter][]=' \
#    -d 'errata_filter[filter_params][doc_status][]=' \
#
# - Using a predefined filter to do this kind of thing is as simple as:
#    curl -s -u: --negotiate https://errata.devel.redhat.com/filter/565.json
#
# - You can add --insecure if you don't have the Red Hat CA cert installed.
#   (See also https://mojo.redhat.com/docs/DOC-926093.)
#
curl -s -u: --negotiate \
  'https://errata.devel.redhat.com/errata' \
  -H 'Accept: application/json' \
  -X 'GET' \
  \
  -d 'errata_filter[filter_params][show_type_RHBA]=1' \
  -d 'errata_filter[filter_params][show_type_RHEA]=1' \
  -d 'errata_filter[filter_params][show_type_RHSA]=1' \
  \
  -d 'errata_filter[filter_params][show_state_NEW_FILES]=1' \
  -d 'errata_filter[filter_params][show_state_QE]=1' \
  -d 'errata_filter[filter_params][show_state_REL_PREP]=1' \
  -d 'errata_filter[filter_params][show_state_PUSH_READY]=1' \
  -d 'errata_filter[filter_params][show_state_IN_PUSH]=' \
  -d 'errata_filter[filter_params][show_state_DROPPED_NO_SHIP]=' \
  -d 'errata_filter[filter_params][show_state_SHIPPED_LIVE]=' \
  \
  -d 'errata_filter[filter_params][release][]=336' \
  -d 'errata_filter[filter_params][release][]=342' \
  \
  -d 'errata_filter[filter_params][synopsis_text]=' \
  -d 'errata_filter[filter_params][group_by]=none' \
  -d 'errata_filter[filter_params][open_closed_option]=' \
  -d 'errata_filter[filter_params][sort_by_fields][]=new' \
  -d 'errata_filter[filter_params][sort_by_fields][]=new' \
  -d 'errata_filter[filter_params][output_format]=standard' \
  -d 'errata_filter[filter_params][pagination_option]=100' \
  \
    | python -m json.tool
