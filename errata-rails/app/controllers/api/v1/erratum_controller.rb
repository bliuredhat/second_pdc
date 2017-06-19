#
# :api-category: Advisories
#
class Api::V1::ErratumController < ApplicationController
  include SharedApi::ErrataBuilds

  respond_to :json

  before_filter :find_errata        , :except => [:create]
  before_filter :set_advisory_form  , :except => [:clone, :change_state, :remove_build]
  before_filter :find_bug           , :only   => [:remove_bug]
  before_filter :find_or_fetch_bug  , :only   => [:add_bug]
  before_filter :filelist_locked?   , :only   => [:add_build, :add_builds, :remove_build, :reload_builds]
  before_filter :is_text_only?      , :only   => [:add_build, :add_builds]
  before_filter :find_jira_issue    , :only   => [:remove_jira_issue]
  before_filter :find_or_fetch_jira_issue, :only => [:add_jira_issue]
  before_filter :batch_admin_restricted, :only => [:change_batch]
  before_filter :reject_batch_params, :only   => [:create, :update]

  around_filter :with_validation_error_rendering, :only => [
    :buildflags,
    :change_batch,
    :update_buildflags,
    :add_comment
  ]

  verify :method => :post, :only => [
    :clone,
    :add_bug,
    :remove_bug,
    :create,
    :change_state,
    :add_jira_issue,
    :remove_jira_issue,
    :reload_builds,
    :change_batch,
    :add_comment,
  ]

  verify :method => :put, :only => [
    :update_buildflags,
  ]

  #
  # Clone an advisory.
  #
  # The request format is the same as for [/api/v1/erratum].  Any
  # present fields override the fields cloned from the original
  # advisory.
  #
  # * **Note:** In order to successfully clone an advisory, you will
  # need to provide a new bug list.
  #
  # * **Note:** Cloning RHSA advisories without a secalert role will
  # change the advisory type to **RHBA**.
  #
  # :api-url: /api/v1/erratum/{id}/clone
  # :api-method: POST
  # :api-request-example: {"advisory":{"idsfixed": "1012312"}}
  #
  def clone
    create_params = AdvisoryForm.clone_errata_by_params(current_user, params)
    @advisory = CreateAdvisoryForm.new(current_user, create_params)
    create
  end

  #
  # Add a bug to an advisory.
  #
  # :api-request-example: {"bug": "884202"}
  # :api-url: /api/v1/erratum/{id}/add_bug
  # :api-method: POST
  #
  def add_bug
    @advisory.bugs.append(@bug.id)
    update
  end

  #
  # Remove a bug from an advisory.
  #
  # :api-url: /api/v1/erratum/{id}/remove_bug
  # :api-method: POST
  # :api-request-example: {"bug": "884202"}
  #
  def remove_bug
    @advisory.bugs.remove(@bug.id)
    update
  end

  #
  # Add a JIRA issue to an advisory.
  #
  # :api-url: /api/v1/erratum/{id}/add_jira_issue
  # :api-method: POST
  # :api-request-example: {"jira_issue": "ABC-12345"}
  #
  def add_jira_issue
    @advisory.jira_issues.append(@jira_issue.key)
    update
  end

  #
  # Remove a JIRA issue from an advisory.
  #
  # :api-url: /api/v1/erratum/{id}/remove_jira_issue
  # :api-method: POST
  # :api-request-example: {"jira_issue": "ABC-12345"}
  #
  def remove_jira_issue
    @advisory.jira_issues.remove(@jira_issue.key)
    update
  end

  #
  # Add a comment to an advisory.
  #
  # :api-url: /api/v1/erratum/{id}/add_comment
  # :api-method: POST
  # :api-request-example: {"comment": "This is my comment"}
  #
  # The response body is the updated or unmodified advisory, in the same format
  # as [GET /api/v1/erratum/{id}].
  #
  def add_comment
    @advisory.errata.comments.create!(
      :who => current_user,
      :text => params[:comment]
    )
    update
  end

  #
  # Create a new advisory.
  #
  # :api-url: /api/v1/erratum
  # :api-method: POST
  #
  # Takes an advisory object and related attributes using the
  # following format:
  #
  # ```` JavaScript
  # {
  #   "advisory": {
  #     "errata_type":"RHSA",
  #     "security_impact":"Low",
  #     ...
  #   },
  #  "product":"RHEL",
  #  ...
  # }
  # ````
  #
  # The following fields are supported.  Fields marked with * are mandatory.
  #
  # * `advisory[errata_type]`*: RHSA, RHBA, RHEA
  # * `advisory[security_impact]`*: None, Low, Moderate, Important, Critical
  # * `product`*: Product short name, eg RHEL, RHEV, RHDevToolset
  # * `release`*: Release name, eg RHEL-7.0.0, ASYNC, RHEL-6-JBEAP-6
  # * `advisory[solution]`*
  # * `advisory[description]`*
  # * `advisory[manager_email]`*
  # * `advisory[package_owner_email]`*
  # * `advisory[synopsis]`*
  # * `advisory[topic]`*
  # * `advisory[idsfixed]`*: Space separated bug ids or JIRA issue keys
  # * `advisory[text_only]`: 1 || 0
  # * `advisory[text_only_cpe]`: CPE Text (RHSA only)
  # * `advisory[cve]`: CVE Names (RHSA only)
  # * `advisory[reboot_suggested]`: 1 || 0 (read-only)
  # * `advisory[keywords]`
  # * `advisory[reference]`: References
  # * `advisory[embargo_date]`: 'YYYY-MM-DD'
  # * `advisory[publish_date_override]`: 'YYYY-MM-DD'
  # * `advisory[text_ready]`: '1' to request docs approval
  # * `advisory[doc_complete]`: '1' to approve docs, '0' to disapprove docs
  # * `advisory[security_approved]`: null for security approval not requested, false for requested, true for approved
  # * `advisory[closed]`: 1 || 0
  # * `advisory[assigned_to_email]`: QE owner email address
  # * `advisory[quality_responsibility_name]`: QE Group name
  # * `advisory[product_version_text]`: Product version names listed in bug comment text when text-only RHSAs are pushed
  #
  # * The `publish_date_override` field is the field refered to
  # as 'Release Date' in the web UI. In most cases this is not required
  # since the advisory's publish date will default to the release's
  # ship date by default.
  #
  def create
    was_new = @advisory.new_record?
    @advisory.save
    respond_with(@advisory, :location => {:action => :show, :id => @advisory})
  end

  #
  # Update an existing advisory.
  #
  # :api-url: /api/v1/erratum/{id}
  # :api-method: PUT
  #
  # Accepts the same list of fields as described for
  # [/api/v1/erratum].  All values you provide will overwrite the
  # existing value and are *not* appended (e.g. `idsfixed` will
  # replace all bugs with the new bugids you provide).
  #
  # A successful update will return no advisory information. Retrieve the
  # advisory afterwards with a [GET /api/v1/erratum/{id}].
  #
  alias_method :update, :create

  #
  # Change the state of an advisory.
  #
  # :api-url: /api/v1/erratum/{id}/change_state
  # :api-method: POST
  # :api-request-example: {"new_state": "QE"}
  #
  # Request body may contain:
  #
  # * `new_state`: e.g. 'QE' (required)
  # * `comment`: a comment to post on the advisory (optional)
  #
  def change_state
    new_state = params[:new_state]
    comment_text = params[:comment]
    begin
      @errata.change_state!(new_state, @user, comment_text)
    rescue ActiveRecord::RecordInvalid => ex
      @errata.errors.add(:base, render_to_string(:inline => ex.message))
    end
    respond_with(@errata)
  end

  #
  # Retrieve the advisory data.
  #
  # Example response body:
  #
  # ```` JavaScript
  # {
  #   "bugs": {
  #     "id_prefix": "bz:",
  #     "bugs": [
  #       {
  #         "bug": {
  #           "is_private": 0,
  #           "is_security": 0,
  #           "priority": "high",
  #           "release_notes": "",
  #           "pm_score": 800,
  #           "bug_status": "VERIFIED",
  #           "flags": "devel_ack+,pm_ack+,qa_ack+,qe_test_coverage+,rhel-7.3.0+",
  #           "is_blocker": 0,
  #           "last_updated": "2016-08-23T15:50:33Z",
  #           "reconciled_at": "2016-08-23T21:30:52Z",
  #           "was_marked_on_qa": 1,
  #           "id": 1278781,
  #           "qa_whiteboard": "",
  #           "keywords": "",
  #           "alias": "",
  #           "bug_severity": "",
  #           "is_exception": 0,
  #           "issuetrackers": "",
  #           "short_desc": "[RHEL-7.2] targetcli crashed with many block backstores",
  #           "package_id": 16718,
  #           "verified": ""
  #         }
  #       }
  #     ],
  #     "to_fetch": [],
  #     "errata": {
  #       "rhba": {
  #         "contract": null,
  #         "manager_id": 84974,
  #         "priority": "normal",
  #         ...
  #         "created_at": "2016-08-02T16:21:14Z",
  #         "current_state_index_id": 133069,
  #         "reporter_id": 3000610
  #       }
  #     },
  #     "type": "bugs",
  #     "id_field": "id",
  #     "idsfixed": [
  #       "1278781"
  #     ]
  #   },
  #   "content": {
  #     "content": {
  #       "description": "[RHEL-7.2] targetcli crashed with many block backstores",
  #       "doc_review_due_at": null,
  #       "topic": "Updated python-rtslib packages that fix several bugs and add various enhancements are now available.",
  #       "errata_id": 24389,
  #       "obsoletes": "",
  #       "packages": null,
  #       "updated_at": "2016-08-02T16:21:14Z",
  #       "how_to_test": null,
  #       "cve": "",
  #       "id": 21967,
  #       "text_only_cpe": null,
  #       "keywords": "",
  #       "solution": "Before applying this update, make sure all previously released errata\nrelevant to your system have been applied.\n\nFor details on how to apply this update, refer to:\n\nhttps://access.redhat.com/articles/11258",
  #       "crossref": "",
  #       "revision_count": 1,
  #       "multilib": null,
  #       "doc_reviewer_id": 1,
  #       "reference": ""
  #     }
  #   },
  #   "jira_issues": {
  #     "id_prefix": "jira:",
  #     "to_fetch": [],
  #     "jira_issues": [],
  #     "errata": {
  #       "rhba": {
  #         "contract": null,
  #         "manager_id": 84974,
  #         "priority": "normal",
  #         ...
  #         "created_at": "2016-08-02T16:21:14Z",
  #         "current_state_index_id": 133069,
  #         "reporter_id": 3000610
  #       }
  #     },
  #     "type": "jira_issues",
  #     "id_field": "key",
  #     "idsfixed": []
  #   },
  #   "diffs": {},
  #   "errata": {
  #     "rhba": {
  #       "contract": null,
  #       "manager_id": 84974,
  #       "priority": "normal",
  #       "release_date": null,
  #       "errata_id": 24389,
  #       "filelist_locked": 0,
  #       "pushcount": 0,
  #       "update_date": "2016-08-02T16:21:14Z",
  #       "is_valid": 1,
  #       "rating": 0,
  #       "request": 0,
  #       "resolution": "",
  #       "respin_count": 0,
  #       "synopsis": "python-rtslib bug fix and enhancement update",
  #       "updated_at": "2016-08-02T16:27:00Z",
  #       "group_id": 541,
  #       "published": 0,
  #       "revision": 1,
  #       "status_updated_at": "2016-08-02T16:27:00Z",
  #       "supports_multiple_product_destinations": false,
  #       "closed": 0,
  #       "devel_responsibility_id": 3,
  #       "is_batch_blocker": false,
  #       "is_brew": 1,
  #       "rhnqa": 0,
  #       "rhnqa_shadow": 0,
  #       "sign_requested": 0,
  #       "batch_id": null,
  #       "id": 24389,
  #       "old_advisory": null,
  #       "rhn_complete": 0,
  #       "status": "QE",
  #       "text_ready": 1,
  #       "assigned_to_id": 3002426,
  #       "current_tps_run": null,
  #       "docs_responsibility_id": 1,
  #       "package_owner_id": 3000610,
  #       "publish_date_override": null,
  #       "published_shadow": 0,
  #       "qa_complete": 0,
  #       "deleted": 0,
  #       "security_approved": null,
  #       "state_machine_rule_set_id": null,
  #       "filelist_changed": 0,
  #       "mailed": 0,
  #       "old_delete_product": null,
  #       "product_id": 16,
  #       "security_impact": "None",
  #       "doc_complete": 0,
  #       "fulladvisory": "RHBA-2016:24389-01",
  #       "issue_date": "2016-08-02T16:21:14Z",
  #       "pushed": 0,
  #       "quality_responsibility_id": 156,
  #       "severity": "normal",
  #       "text_only": false,
  #       "actual_ship_date": null,
  #       "created_at": "2016-08-02T16:21:14Z",
  #       "current_state_index_id": 133069,
  #       "reporter_id": 3000610
  #     }
  #   },
  #   "who": {
  #     "user": {
  #       ... user who sent GET request
  #     }
  #   },
  #   "params": {
  #     "action": "show",
  #     "id": "24389",
  #     "format": "json",
  #     "controller": "api/v1/erratum"
  #   }
  # }
  # ````
  #
  # :api-url: /api/v1/erratum/{id}
  # :api-method: GET
  #
  def show
    respond_with(@advisory)
  end

  #
  # Change the docs reviewer for an advisory.
  #
  # :api-url: /api/v1/erratum/{id}/change_docs_reviewer
  # :api-method: POST
  # :api-request-example: {"login_name": "rjoost@redhat.com"}
  #
  # Request body may contain:
  #
  # * login_name - login name or email of the new doc reviewer
  # * comment - optional comment
  #
  def change_docs_reviewer
    begin
      user_id = User.enabled.find_by_login_name!(params[:login_name]).id
    rescue ActiveRecord::RecordNotFound => ex
      @advisory.errata.errors.add(:base, render_to_string(:inline => ex.message))
    else
      @advisory.change_docs_reviewer(user_id, params[:comment])
      @advisory.save
    end
    respond_with(@advisory.errata)
  end

  #
  # Change the batch details for an advisory.
  #
  # :api-url: /api/v1/erratum/{id}/change_batch
  # :api-method: POST
  # :api-request-example: {"batch_name": "batch_123", "is_batch_blocker": true}
  #
  # Request body may contain:
  #
  # * batch_id - id of the batch (integer)
  # * batch_name - name of the batch (string) - alternative to batch_id
  # * clear_batch - removes erratum from batch (boolean)
  # * is_batch_blocker - indicates if advisory blocks batch (boolean)
  #
  # A maximum of one of (batch_id, batch_name, clear_batch) may be specified
  # per request.
  #
  def change_batch
    batch_keys = params.slice(:batch_id, :batch_name, :clear_batch).keys
    if batch_keys.count > 1
      raise DetailedArgumentError.new(
        Hash[batch_keys.map{|k| [k, "Only one of parameters (#{batch_keys.join(', ')}) may be specified"]}]
      )
    elsif batch_keys.count == 0 && !params.key?(:is_batch_blocker)
      raise DetailedArgumentError.new(:params => 'Missing parameters')
    end
    if !@errata.can_edit_batch?
      return show_error("Batch details cannot be edited. Errata state is #{@errata.status}")
    end
    begin
      if params.key?(:batch_id)
        batch = Batch.find_by_id!(params[:batch_id])
      elsif params.key?(:batch_name)
        batch = Batch.find_by_name!(params[:batch_name])
      else
        batch = nil
      end
    rescue ActiveRecord::RecordNotFound => ex
      @errata.errors.add(:base, render_to_string(:inline => ex.message))
    else
      @errata.batch = batch if batch || params[:clear_batch]

      if params.key?(:is_batch_blocker)
        is_batch_blocker = params[:is_batch_blocker]
        if [true, false].include?(is_batch_blocker)
          @errata.is_batch_blocker = is_batch_blocker
        else
          raise DetailedArgumentError.new(:is_batch_blocker => "expected boolean, got #{is_batch_blocker.class}")
        end
      end

      @errata.save
    end
    respond_with(@errata)
  end

  #
  # Removes a Brew build.
  #
  # The build should be indentified by its nvr.
  #
  # :api-url: /api/v1/erratum/{id}/remove_build
  # :api-request-example: {"nvr": "gimp-2.8.8-2.el7"}
  # :api-method: POST
  # :api-category: Builds
  #
  # * `nvr`: the nvr of the build
  #
  def remove_build
    if errata = remove_builds_from_errata(@errata, {params[:nvr] => {}})
      respond_with(errata, :location => nil)
    end
  end

  #
  # Schedule reloading the files list of every brew build in the advisory.
  #
  # Returns a [job tracker][/api/v1/job_trackers/{id}] which may be used
  # to track the reload.
  #
  # The response status is `201 Created`.  The `Location` header
  # in the response will contain the URL of the created job tracker, which may
  # be polled to determine the status of the job.
  #
  # :api-url: /api/v1/erratum/{id}/reload_builds
  # :api-method: POST
  # :api-category: Builds
  #
  # Request body may contain:
  #
  # * no_rpm_listing_only - Reload RPM brew builds that have missing product listings only. Default to false.
  # * no_current_files_only - Reload brew builds for this advisory that have no current files records.
  #
  def reload_builds
    mappings = @errata.build_mappings
    message = "Reload the files list in each brew build for this advisory."
    redirect = params[:redirect].to_bool

    if params[:no_rpm_listing_only].to_bool
      mappings = mappings.for_rpms.without_product_listings
      message = "Reload brew builds for this advisory that have no product listings."
    elsif params[:no_current_files_only].to_bool
      mappings = mappings.for_rpms.without_current_files
      message = "Reload brew builds for this advisory that have no current files records."
    end

    unless mappings.any?
      message = "Advisory '#{@errata.advisory_name}' has no builds to reload."
      if !redirect
        render :json => { :error => message }, :status => :unprocessable_entity
      else
        flash[:error] = message
        redirect_to :back
      end
      return
    end

    tracker = JobTracker.track_jobs(
      "Reload Builds for #{@errata.advisory_name}",
      message,
      :max_attempts => 5
    ) do
      mappings.each do |m|
        BrewJobs::ReloadFilesJob.enqueue(m, @errata.is_pdc?)
      end
    end

    if redirect
      redirect_to :action => :show, :controller => '/job_trackers', :id => tracker
    else
      respond_with(tracker)
    end
  end

  #
  # Adds a brew build to an advisory, for a specified product version or pdc release.
  #
  # :api-url: /api/v1/erratum/{id}/add_build
  # :api-method: POST
  # :api-request-example: {"product_version": "RHEL-7", "nvr": "gimp-2.8.8-2.el7"}
  # :api-request-example: {"pdc_release": "ceph-2.1-updates@rhel-7", "nvr": "ceph-10.2.5-22.el7cp"}
  # :api-category: Builds
  #
  # * `product_version`: product version by name
  # * `pdc_release`: PDC release by PDC release id
  # * `nvr`:  the name-version-release of the build
  #
  # **Note:** this method only supports adding one build per
  # request, and only adds RPMs.  New code should consider using
  # [/api/v1/erratum/{id}/add_builds] instead. `product_version`
  # and `pdc_release` can not be used together.
  #
  def add_build
    # Let add_builds do the work after minor adjustment of params
    params[:build] = params.delete(:nvr)
    params[:file_types] = ['rpm']
    add_builds
  end

  #
  # Add one or more brew builds to an advisory.
  #
  # The request body is a single object or an array of objects
  # specifying builds to add, along with the desired product version
  # (or pdc release) and file type(s). Builds may be specified by ID or NVR.
  #
  # :api-url: /api/v1/erratum/{id}/add_builds
  # :api-method: POST
  # :api-request-example: {"product_version": "RHEL-7", "build": "rhel-server-docker-7.0-23", "file_types": ["ks","tar"]}
  # :api-request-example: {"pdc_release": "ceph-2.1-updates@rhel-7", "build": "ceph-10.2.5-22.el7cp"}
  # :api-category: Builds
  #
  # Example adding multiple builds, mixing build ID and NVR:
  #
  # ```` JavaScript
  # [
  #   {"product_version": "RHEL-7", "build": 367585, "file_types": ["rpm","msi","zip"]},
  #   {"product_version": "RHEL-7", "build": "org.picketbox-picketbox-infinispan-4.0.9.Final-1", "file_types": ["pom", "jar"]}
  #   {"pdc_release": "ceph-2.1-updates@rhel-7", "build": "ceph-10.2.5-22.el7cp"}
  # ]
  # ````
  #
  # Build attributes:
  #
  # * `product_version`: name or ID of an available product version for the advisory
  # * `pdc_release`: PDC release by PDC release id
  # * `build`: nvr or ID of an existing and appropriately tagged brew build
  # * `file_types`: list of one or more file types to be added to the advisory
  #
  # Valid file types include "rpm" for RPMs (the default), and the
  # short name used for archive types within brew, typically based on
  # the file extension (e.g. "ks" for "rhel-7-server-docker.ks").
  #
  # The available file types for a build may be inspected using
  # [/api/v1/build/{id_or_nvr}].
  #
  def add_builds
    build_list = params.include?('_json') ? (params['_json'] || []) : [params]
    to_add = {}

    build_list.each do |arg|
      unless build_id = arg['build']
        raise DetailedArgumentError.new(:build => 'missing id or nvr')
      end

      build = BrewBuild.make_from_rpc_without_mandatory_srpm(build_id, :fail_on_missing => false)
      if !build
        return show_error("No such build #{build_id}")
      end

      if arg['product_version'] && arg['pdc_release']
        return show_error("Can not add a build to ET product version and PDC release at the same time.")
      end

      prod_ver_or_pdc_rel = arg['product_version'] || arg['pdc_release']
      to_add.deep_merge!(
        build.nvr => {
          :product_versions => {
            prod_ver_or_pdc_rel => {
              :file_types => arg['file_types'] || ['rpm']}}})
    end

    if errata = add_builds_to_errata(@errata, to_add)
      respond_with(errata, :location => nil)
    end
  end

  # Get flags associated with builds within an advisory.
  #
  # :api-url: /api/v1/erratum/{id}/buildflags
  # :api-method: GET
  # :api-category: Builds
  # :api-response-example: file:test/data/api/v1/buildflags/put_by_pv.json
  #
  # Returns an array with an element for each build which has any
  # build flags set, along with the associated product version and
  # file type.
  #
  # In the most common case that no build flags are set, the response
  # will be an empty array.
  #
  def buildflags
    @mappings = find_mappings_with_flags
  end

  # Set flags associated with a build within an advisory.
  #
  # :api-url: /api/v1/erratum/{id}/buildflags
  # :api-method: PUT
  # :api-category: Builds
  #
  # The request body is a single object or an array of objects mapping
  # build(s) to the desired flags.  Each object can have the following
  # properties:
  #
  # * `build`: ID or NVR of a brew build
  # * `product_version`: ID or name of a product version
  # * `file_type`: name of a file type (e.g. "rpm", "zip")
  # * `flags`: array of build flags
  #
  # `flags` is the only mandatory property.  The other properties are
  # applied as filters - flags are updated only for builds matching
  # all of the given criteria.
  #
  # The newly requested flags overwrite any previously set flags.
  #
  # Currently there is one supported flag, buildroot-push, which
  # requests that a build be tagged into brew buildroots ASAP to
  # facilitate testing (RPMs only).
  #
  # Example: set buildroot-push flag for all RPMs in this advisory:\
  #   `{"file_type": "rpm", "flags": ["buildroot-push"]}`
  #
  # Example: set buildroot-push flag only for RPMs in a particular
  # product version, unset flags in another product version.
  #
  # ```` JavaScript
  # [
  #   {"product_version": "RHEL-7", "file_type": "rpm", "flags": ["buildroot-push"]},
  #   {"product_version": "RHEL-7-RHEV", "flags": []}
  # ]
  # ````
  #
  # The response code is 201 if any data was modified, 200 otherwise.
  # The response body is the updated or unmodified object, in the same
  # format as [GET /api/v1/erratum/{id}/buildflags].
  #
  # TODO: Support PDC
  def update_buildflags
    unless @errata.is_legacy?
      raise DetailedArgumentError, errata: 'Unsupported for PDC Advisories'
    end

    updates = if params.include?('_json')
      params['_json'] || []
    else
      [params.slice(*%w[build product_version file_type flags])]
    end

    mapping_to_flags = extract_mapping_to_flags(updates)
    modified = ActiveRecord::Base.transaction do
      update_mapping_flags(mapping_to_flags)
    end

    @mappings = find_mappings_with_flags
    render 'buildflags', :status => modified ? 201 : 200
  end

  # Get RPM files mapped by variant per each build within an advisory.
  #
  # :api-url: /api/v1/erratum/{id}/get_variant_rpms
  # :api-method: GET
  # :api-category: Builds
  # :api-response-example: file:test/data/api/v1/erratum/20291/get_variant_rpms.json
  #
  # Returns an object containing builds which have RPM files mapped
  # by variant.
  # For the advisory supporting multi-product destinations, it also
  # includes data from mapped products.
  #
  def get_variant_rpms
    mappings = Hash.new { |h, k| h[k] = {
                            :variant_files => HashSet.new, :mapped_variant_files => HashSet.new } }
    collect_dists = lambda do |brew_build, file, variant, arch, dists, mapped_dists|
      variants = Array.wrap(dists).map(&:variant).map(&:name).uniq
      mapped_variants = Array.wrap(mapped_dists).map(&:variant).map(&:name).uniq
      variants.each { |v| mappings[brew_build][:variant_files][v] << file.rpm_name }
      mapped_variants.each { |v| mappings[brew_build][:mapped_variant_files][v] << file.rpm_name }
    end

    options = {:supports_multi_product_destinations =>
               @errata.supports_multiple_product_destinations?}
    Push::Rhn.file_channel_map(@errata, options, &collect_dists)
    Push::Cdn.file_repo_map(@errata, options, &collect_dists)

    respond_with(mappings)
  end

  private

  def show_error(error_msg)
    render :json => { :error => error_msg }, :status => :unprocessable_entity
    nil
  end

  def filelist_locked?
    unless @errata.filelist_unlocked?
      return show_error "Filelist is locked. State must be NEW_FILES to update builds"
    end
  end

  def is_text_only?
    if @errata.text_only?
      return show_error "Can not add builds to text only advisories"
    end
  end

  # duplicate, from errata_controller.rb
  def set_advisory_form
    prepare_advisory_params
    find_product_and_release
    @advisory = UpdateAdvisoryForm.new(User.current_user, params) if params[:id]
    @advisory ||= CreateAdvisoryForm.new(User.current_user, params)
    @errata = @advisory.errata
  end

  # Convert the name of the product and release to an id hash
  def find_product_and_release
    params[:product] = { :id => Product.active_products.find_by_short_name( params[:product]).try(:id) } if params[:product]
    params[:release] = { :id => Release.current.enabled.find_by_name(       params[:release]).try(:id) } if params[:release]
  end

  def find_bug(fetch = false)
    bug_id = params[:bug]
    return false if bug_id.nil?

    @bug = Bug.find_by_id(bug_id)
    if @bug.nil? && fetch && Bug.looks_like_bug_id(bug_id)
      @bug = Bug.batch_update_from_rpc([bug_id]).first
    end

    if @bug.nil?
      redirect_to_error!("invalid or unknown bug #{bug_id}", :bad_request)
    end
  end

  def find_or_fetch_bug
    find_bug(true)
  end

  def find_jira_issue(allow_fetch = false)
    key = params[:jira_issue]
    if key.blank?
      redirect_to_error!('missing jira issue parameter in request', :bad_request)
      return
    end

    @jira_issue = JiraIssue.find_by_key(key)
    if @jira_issue.nil? && JiraIssue.looks_like_issue_key(key) && allow_fetch
      @jira_issue = JiraIssue.batch_update_from_rpc([key], :permissive => true).first
    end

    if @jira_issue.nil?
      redirect_to_error!("invalid or unknown jira issue #{key}", :bad_request)
    end
  end

  def find_or_fetch_jira_issue
    find_jira_issue(true)
  end

  def prepare_advisory_params
    return unless advisory_params = params[:advisory]

    # Don't want api users to have to deal with our badly named columns.
    advisory_params[:release_date] = advisory_params.delete(:embargo_date) if advisory_params.has_key?(:embargo_date)

    # Have to set these to enable the date fields
    advisory_params[:enable_embargo_date] = 'on' if advisory_params[:release_date]
    advisory_params[:enable_release_date] = 'on' if advisory_params[:publish_date_override]
    # change errata type to pdc type if release is_pdc is true
    is_pdc = Release.current.enabled.find_by_name(params[:release]).try(:is_pdc) if params[:release]
    # maybe in updating
    if !is_pdc && params[:id]
      is_pdc = Errata.find(params[:id]).is_pdc?
    end
    if is_pdc && advisory_params[:errata_type] && advisory_params[:errata_type].classify.constantize < LegacyErrata
      advisory_params[:errata_type].prepend('Pdc')
    end
  end

  def find_mappings_with_flags
    @errata.build_mappings.
      reject{|m| m.flags.empty?}.
      sort_by{|m| [m.brew_build_id, m.product_version_id, m.brew_archive_type_id || -1]}
  end

  def extract_mapping_to_flags(param_list)
    param_list.reduce(HashList.new) do |h,p|
      raise DetailedArgumentError.new(:flags => 'missing argument') unless p.include?('flags')

      flags = p['flags'] || []

      mappings = @errata.errata_brew_mappings.to_a


      [['build',
        :brew_build,
        lambda{|id| BrewBuild.find_by_id_or_name(id, 'nvr')}],

       ['product_version',
        :product_version,
        ProductVersion.method(:find_by_id_or_name)],

       ['file_type',
        :file_type_name,
        lambda{|id| id}]
      ].each do |key,attr,finder|
        id = p[key]
        next unless id

        if !id.kind_of?(String) && !id.kind_of?(Integer)
          raise DetailedArgumentError.new(key => "wrong argument type #{id.class}")
        end

        record = finder.call(id)
        mappings = mappings.select{|m| m.send(attr) == record}
      end

      mappings.each do |m|
        h[m] << flags.to_set
      end

      h
    end
  end

  def update_mapping_flags(mapping_to_flags)
    modified = false
    mapping_to_flags.each do |m,all_flags|
      flags = all_flags.uniq
      if flags.length != 1
        raise DetailedArgumentError.new(:flags =>
          "conflicting flags requested for build #{m.brew_build.nvr}, product version #{m.product_version.name}, " +
          "file type #{m.file_type_name}")
      end
      flags = flags.first

      if m.flags != flags
        m.flags = flags
        m.save!
        modified = true
      end
    end

    @errata.reload if modified
    modified
  end

  # FIXME: is there a way I can let rails figure this out automatically from routes?
  # It seems unable to find it unless I put it as a top-level resource, which clobbers the
  # routes for the non-api job_trackers_controller.
  def job_tracker_url(tracker)
    url_for :controller => :job_trackers, :action => 'show', :id => tracker
  end

  def reject_batch_params
    advisory_params = params[:advisory]
    return if advisory_params.nil?

    if advisory_params.slice(:batch_id, :batch_name, :batch, :is_batch_blocker).any?
      redirect_to_error!('Use change_batch API to set batch details', :unprocessable_entity)
    end
  end

end
