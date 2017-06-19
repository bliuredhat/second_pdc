# :api-category: Pushing Advisories
class Api::V1::ErratumPushController < ApplicationController
  include SharedApi::ErrataPush

  respond_to :json

  around_filter :with_validation_error_rendering

  before_filter :find_errata
  before_filter :find_push_job, :except => [
    :create,
    :index,
  ]

  WRITE_METHODS = [
    :create,
  ]
  verify        :method => :post,  :only => WRITE_METHODS

  #
  # Get the push history of an advisory.
  #
  # :api-url: /api/v1/erratum/{id}/push
  # :api-method: GET
  # :api-response-example: file:test/data/api/v1/erratum_push/index/errata_11131.json
  #
  # Responds with an array of pushes for this advisory.  The fields on
  # each push object are documented under
  # [/api/v1/erratum/{id}/push/{push_id}].
  #
  def index
  end

  #
  # Get the details of an advisory push.
  #
  # :api-url: /api/v1/erratum/{id}/push/{push_id}
  # :api-method: GET
  # :api-response-example: file:test/data/api/v1/erratum_push/show/push_9883_161.json
  #
  # Responds with an object with the following keys:
  #
  # * `id`: unique ID of this push
  # * `url`: unique URL of this push in Errata Tool's API
  # * `errata`: an object holding the advisory's ID
  # * `pub_task`: an object holding the ID of the corresponding pub task
  # * `log`: plain text log of the push
  # * `status`: the status of the push, one of: READY, RUNNING, QUEUED, WAITING_ON_PUB, COMPLETE, FAILED
  # * `target`: an object holding the ID and name of the push target
  # * `options`: option key/values as passed to pub
  # * `pre_push_tasks`: the pre-push tasks used for this job (in no
  #                     particular order)
  # * `post_push_tasks`: the post-push tasks used for this job (in no
  #                      particular order)
  #
  def show
  end

  #
  # Perform one or more advisory pushes.
  #
  # :api-url: /api/v1/erratum/{id}/push
  # :api-url: /api/v1/erratum/{id}/push?defaults=stage
  # :api-url: /api/v1/erratum/{id}/push?defaults=live
  # :api-method: POST
  #
  # To select push targets, the body of the request should contain an
  # array of push target specifiers.  (As a convenience, if only one
  # target is being pushed, it's unnecessary to use an array.)
  #
  # Each push target specifier may contain the properties:
  #
  # * `target`: name of the push target, e.g. cdn, cdn_stage, rhn_live,
  #             rhn_stage, altsrc, ftp
  #
  # * `skip_pushed`: if true, do not push this target if it has already
  #                  successfully pushed since last respin.  This option is
  #                  implied when using `defaults` parameter.
  #
  # * `skip_in_progress`: if true, do not push this target if a push job is
  #                       already in progress. This option is implied when using
  #                       `defaults` parameter.
  #
  # * `options`: an object whose properties define options for the push,
  #              e.g. `{"priority": 20}`.  An array may be used as
  #              shorthand if the value of every passed option should be
  #              true, e.g. `["shadow"]` is equivalent to `{"shadow":
  #              true}`.
  #
  # * `append_options`: an object specifying additional options for the push.
  #                     An array may be used, as described for `options`.
  #
  # * `exclude_options`: an array of options to be excluded. This overrides
  #                      any options specified elsewhere. No error is returned
  #                      if an excluded option was not going to be used.
  #
  # * `pre_tasks, post_tasks`: arrays specifying pre/post-push tasks to
  #                            be enabled for this push.
  #                            e.g. `["set_update_date","set_issue_date"]`.
  #
  # * `append_pre_tasks, append_post_tasks`: arrays specifying additional
  #               pre/post-push tasks to be performed, in addition to tasks
  #               specified by `pre_tasks` and `post_tasks` (or default tasks).
  #
  # * `exclude_pre_tasks, exclude_post_tasks`: arrays specifying pre/post-push
  #               tasks to be excluded. These tasks will not be performed. No
  #               error will be returned if any excluded task was not in the
  #               list of tasks to be performed.
  #
  # Only target is mandatory.  The other properties use appropriate
  # defaults if omitted, (the same values as would be enabled by
  # default when using the UI to trigger a push).
  #
  # **Note**: setting options, pre_tasks or post_tasks _overwrites_ the
  # default values for that property, rather than appending to them. Use
  # the `append_*` parameters to append options or tasks.
  #
  # Valid target, option and pre/post-task names are listed in
  # [Push Targets, Options and Tasks](#push-push-targets-options-and-tasks).
  #
  # Please note that the valid target, option and pre/post-task names
  # for an advisory depend on the configuration of Errata Tool and may
  # change without notice.
  #
  # As an alternative to explicitly listing the push targets to be
  # used, the 'defaults' query parameter may be set to push to all
  # applicable targets for the advisory.  Set `defaults=stage`
  # to push to staging targets, `defaults=live` to push to live
  # targets.  When using defaults, leave the request body empty.
  #
  # Using 'defaults' will not redo any push which has already
  # successfully completed since the last respin of the advisory.
  # It will redo failed pushes.
  #
  # Responds with an array containing an object for each triggered
  # push.  Each object uses the format described by
  # [/api/v1/erratum/{id}/push/{push_id}].
  #
  # Example: Perform every applicable live push:
  #
  # * POST to: `/api/v1/erratum/12345/push?defaults=live`
  # * With request body: (none)
  #
  # Example: Push to RHN and CDN stage:
  #
  # * POST to: `/api/v1/erratum/12345/push`
  # * With request body:\
  #      `[{"target":"rhn_stage"},{"target":"cdn_stage"}]`
  #
  # Example: Do an RHN shadow push:
  #
  # (note it's necessary to disable most pre/push tasks)
  #
  # * POST to: `/api/v1/erratum/12345/push`
  # * With request body:\
  #      `{"target":"rhn_live","options":["shadow"],"pre_tasks":[],"post_tasks":[]}`
  #
  # Example: Do a metadata-only RHN push:
  #
  # * POST to: `/api/v1/erratum/12345/push`
  # * With request body:\
  #      `{"target":"rhn_live","options":{"push_metadata":true,"push_files":false}}`
  #
  def create
    push_requests = PushRequest.from_errata_and_params(@errata, params)

    # expecting to push exactly one advisory
    raise "internal error; #{push_requests.length} errata for push..." \
      unless push_requests.length == 1

    push_request = push_requests.first

    push_jobs = create_push_jobs(push_request)
    push_jobs.each(&:submit!)

    status = push_jobs.any? ? 201 : 200
    render '/api/v1/shared/_push_job_list', :locals => {:push_jobs => push_jobs}, :status => status
  end

  private

  def find_push_job
    @push_job = PushJob.find_by_id(params[:id])
    @push_job = nil unless @push_job && @push_job.errata == @errata

    return redirect_to_error!("Push job not found") unless @push_job
  end

end
