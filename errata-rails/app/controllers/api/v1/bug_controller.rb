# :api-category: Bugs
class Api::V1::BugController < ApplicationController
  include ApplicationHelper

  respond_to :json

  # Request Errata Tool to update its copy of one or more Bugzilla bugs.
  #
  # :api-url: /api/v1/bug/refresh
  # :api-method: POST
  # :api-request-example: [726799,1169890,"7.0z-kernel3","CVE-2009-1866"]
  #
  # Accepts an array of bug numbers and aliases.
  #
  # Errata Tool usually synchronizes Bugzilla updates automatically,
  # but there's an unpredictable delay between a bug being updated in
  # Bugzilla and Errata Tool becoming aware of the update.  This API
  # may be used to eliminate race conditions caused by this delay.
  #
  # In particular, if a system wants to update some bugs in Bugzilla
  # and then use the updated bugs in Errata Tool, it's useful to
  # invoke this API between those two steps to ensure the bug updates
  # have reached Errata Tool.
  #
  # Responds with a status of 204 (no content) and an empty body after
  # syncing the bugs.
  #
  # Will respond with a status of 404 (not found) if any of the bugs
  # can't be found in Bugzilla.
  #
  def refresh
    to_sync = params['_json']

    unless to_sync.kind_of?(Array)
      return redirect_to_error!('request body must contain a valid JSON array of bug numbers or aliases', :bad_request)
    end

    updated = Bug.batch_update_from_rpc(to_sync, :permissive => true)
    # Get all the bug ids and aliases we found so we can check if
    # there was anything requested that we _didn't_ find.  Note the
    # special handling of aliases, because we store them in the DB as
    # a comma-separated string :(
    updated_ids_and_aliases = updated.
      map{|b| [b.id, b.alias.split(/,\s*/)]}.
      flatten.map(&:to_s).uniq
    not_updated = to_sync.map(&:to_s) - updated_ids_and_aliases

    if not_updated.any?
      return redirect_to_error!(
        "#{n_thing_or_things(not_updated.length, 'bug')} not found: #{display_list_with_and(not_updated, :elide_after => 4)}", :not_found)
    end

    render :nothing => true, :status => 204
  end
end
