# :api-category: Pushing Advisories
class Api::V1::PushController < ApplicationController
  include SharedApi::ErrataPush
  include SharedApi::Paginate

  respond_to :json

  around_filter :with_validation_error_rendering

  before_filter :set_targets, :set_default_states, :only => [:create]
  before_filter :create_filter, :process_errata_filter, :only => [:create, :index]
  before_filter :set_errata_includes, :only => [:create]
  before_filter :process_push_job_filter, :only => [:index]
  before_filter :find_push_job, :only => [:show]

  verify :method => :get, :only => [:index, :show]
  verify :method => :post, :only => [:create]

  #
  # Perform one or more advisory pushes.
  #
  # :api-url: /api/v1/push
  # :api-url: /api/v1/push?defaults=live&filter[x]=y
  # :api-method: POST
  #
  # This API is similar to [POST /api/v1/erratum/{id}/push], but may be used to
  # push a collection of related errata, such as a batch or release.
  #
  # Supported parameters include:
  #
  # * `filter`: see below
  #
  # * `defaults`: as for [POST /api/v1/erratum/{id}/push]
  #
  # * `dryrun`: if set to 1, do not actually do a push, only verify that the
  #             requested push can be done.  In this case, the response will
  #             include the push jobs which would have been created.
  #
  # The `filter` parameters are used to determine the collection of errata
  # applicable for push.
  #
  # The available fields for usage with `filter` include:
  #
  # * `batch_name`, `batch_id`: name or ID of the batch to which the advisory
  #                             belongs, e.g. "RHEL-7.2.2"
  #
  # * `release_name`, `release_id`: name or ID of the release, e.g. "RHEL-7.2.Z"
  #
  # * `errata_name`, `errata_id`: name or ID of an advisory, e.g.
  #                               "RHBA-2016:0132-02" or 22606
  #
  # * `errata_status`: status of the errata, e.g. "PUSH_READY".  Omitted (recommended)
  #                    means all applicable status for the given push targets.
  #
  # Note that certain combinations of `filter` fields may be disallowed.
  #
  # The `defaults` parameter and the body of the request are used to specify the
  # targets and options for push.  Please see [POST /api/v1/erratum/{id}/push]
  # for the behavior of these.
  #
  # Note that the pub tasks for the push jobs are not created by the time
  # this API responds, but rather are created asynchronously shortly afterward.
  #
  # This API responds with an array of push jobs, each using the same format as
  # [GET /api/v1/push/{id}].  The response will include only
  # the jobs created during the request.
  #
  # If a request completes successfully, all requested push jobs were created
  # (or already existed).  If the request is unsuccessful, no push jobs were
  # created.
  #
  # *Warning*: when triggering many push jobs (hundreds or more), this API may
  # take a few minutes to respond.  If this is a concern, consider splitting a
  # push request to multiple smaller requests.
  #
  # Example: Trigger live push of RHEL-7.2.2 batch:
  #
  # * POST to: `/api/v1/push?defaults=live&filter[batch_name]=RHEL-7.2.2`
  # * With request body: (none)
  # * Creates push jobs for all PUSH_READY or IN_PUSH RHEL-7.2.2 errata
  # * Creates push jobs of all default live types (e.g. RHN, CDN, FTP) with default options
  #
  # Example: Trigger CDN push of RHEL-7.3.0 release:
  #
  # * POST to: `/api/v1/push?filter[release_name]=RHEL-7.3.0`
  # * With request body:\
  #      `{"target":"cdn"}`
  # * Creates CDN push jobs for all PUSH_READY or IN_PUSH RHEL-7.3.0 errata
  # * Unlike previous example, will trigger CDN push even for errata already pushed
  #   successfully to CDN
  #
  def create
    # This is a safeguard against accidentally pushing too much.
    unless @have_acceptable_filter
      raise DetailedArgumentError.new(
              :filter => 'must specify release, batch or errata when using ' +
                         'this API')
    end

    push_requests = PushRequest.from_errata_and_params(@errata, params)

    created_jobs = []

    ActiveRecord::Base.transaction_with_retry do
      created_jobs = create_push_jobs_for_requests(push_requests)

      # Jobs are now created, but not submitted to pub.  Do that ASAP,
      # asynchronously.
      #
      # It's asynchronous because we can't do it transactionally (can't roll back
      # task creation in pub), it might be slow (hundreds of RPC calls to pub),
      # and it's hard to use this API if it could fail halfway through creating
      # pub tasks.
      PushJob.submit_jobs_later(created_jobs)

      raise ActiveRecord::Rollback if dryrun?
    end

    status = (!dryrun? && created_jobs.any?) ? :created : :ok
    render '/api/v1/shared/_push_job_list', :locals => {:push_jobs => created_jobs}, :status => status
  end

  #
  # Get details about push jobs.
  #
  # :api-url: /api/v1/push
  # :api-url: /api/v1/push?filter[x]=y
  # :api-method: GET
  #
  # The `filter` parameters are used to determine the push jobs found.
  #
  # The available fields for usage with `filter` include:
  #
  # * all the same fields as [POST /api/v1/push]
  #
  # * `id`: Errata Tool's ID of a push job
  #
  # * `pub_task_id`: pub's ID of a push task
  #
  # * `target_name`: name of push target, e.g. "cdn", "rhn_live", or the special
  #                  values "live" or "stage" to match all live/stage targets.
  #
  # * `current`: only include current push jobs (the latest job of each type per
  #              errata).  By default, older jobs are also returned.
  #
  # This is a [paginated API].
  #
  def index
    @push_jobs = apply_pagination(@push_jobs)
  end

  #
  # Get the details of an advisory push.
  #
  # :api-url: /api/v1/push/{id}
  # :api-method: GET
  #
  # Identical to [GET /api/v1/erratum/{id}/push/{push_id}].
  def show
  end

  private

  # Process the @query_filter and set:
  #
  #  @errata - the errata to be pushed or fetched
  #
  #  @have_errata_filter    - true if errata is filtered on anything
  #  @have_acceptable_filter - true if filter is acceptably narrow for
  #                            triggering push
  #
  def process_errata_filter
    joins = []
    where = []
    @have_acceptable_filter = false

    if (value = extract_filter(Release, :name))
      @have_acceptable_filter = true
      joins << :release
      where << {:releases => {:name => value}}
    end

    if (value = extract_filter(Release, :id))
      @have_acceptable_filter = true
      where << {:group_id => value}
    end

    if (value = extract_filter(Batch, :name))
      @have_acceptable_filter = true
      joins << :batch
      where << {:batches => {:name => value}}
    end

    if (value = extract_filter(Batch, :id))
      @have_acceptable_filter = true
      where << {:batch_id => value}
    end

    %w(errata_id errata_name).each do |errata_key|
      # Note these fields are interchangeable for historical & usability reasons
      if (value = extract_errata_id_or_name(errata_key))
        @have_acceptable_filter = true
        where << {:id => value}
      end
    end

    # Note status works a bit differently from others, since:
    # - the set of valid values is just a constant, not a set of records
    # - default values may apply if the user hasn't set any.
    if (value = extract_errata_status_filter)
      where << {:status => value}
    elsif @default_states.present?
      where << {:status => @default_states}
    end

    @errata = filtered_relation(Errata, where, joins)
    @have_errata_filter = where.any?

    Rails.logger.debug "Filtered errata: #{@errata.to_sql}"
  end

  # Extracts, validates and returns filter values from @query_filter for the given
  # ActiveRecord +klass+ and +attribute+.
  def extract_filter(klass, attribute)
    # [FooBar, :name] => "foo_bar_name"
    field_name = klass.name.underscore
    key = "#{field_name}_#{attribute}"
    values = Array.wrap(@query_filter[key])
    return if values.empty?

    valid_values = klass.where(attribute => values).map(&attribute)
    ensure_filter_match!(key, values, valid_values,
                         "#{field_name} not found with #{attribute} = ")

    # Although we loaded the records already, we just return the passed in values, they'll
    # be used from a join.
    values
  end

  # Extracts, validates and returns errata_status from @query_filter.
  def extract_errata_status_filter
    values = Array.wrap(@query_filter['errata_status'])
    return if values.empty?
    ensure_filter_match!('errata_status', values, State::ALL_STATES, 'invalid status: ')
    values
  end

  # Extracts, validates, maps to IDs and returns errata identifiers from @query_filter
  # for the specified +errata_key+.
  #
  # +errata_key+ is expected to be errata_id or errata_name, but they're both
  # handled the same way, e.g. id can be passed as name and vice-versa.
  #
  # Advisory "id" and "name" are generally accepted interchangeably in
  # various places in the API and UI, so we do the same here by using the
  # fuzzy matching in find_by_advisory.
  def extract_errata_id_or_name(errata_key)
    values = Array.wrap(@query_filter[errata_key])
    return if values.empty?

    errata = values.map do |id_or_name|
      begin
        Errata.find_by_advisory(id_or_name)
      rescue BadErrataID
        # will raise later
      end
    end.compact

    valid_values = errata.map do |e|
      [e.id, e.fulladvisory, e.advisory_name]
    end.flatten

    ensure_filter_match!(errata_key, values, valid_values, 'not found: ')

    errata.map(&:id)
  end

  # Raise an appropriate error if any of +passed_values+ (for parameter +key+) is not
  # in the set of +valid_values+.  +message+ will be included in the error.
  def ensure_filter_match!(key, passed_values, valid_values, message)
    if request.get?
      # For GET, it's not necessary to validate the values. Objects which don't exist
      # simply don't match the search.
      # For POST, we want to validate since the user's request to create push jobs
      # relating to nonexistent objects can't be satisfied.
      return
    end

    # It's valid to pass some non-string types (like integers) as a string
    valid_values = valid_values + valid_values.map(&:to_s)

    invalid_values = passed_values - valid_values
    return if invalid_values.empty?

    message += invalid_values.sort.join(', ').truncate(80)
    raise DetailedArgumentError.new(key => message)
  end

  def set_errata_includes
    # A lot of data needs to be accessed to decide if a push is permitted.  This
    # helps cut down the number of queries a bit when operating on many errata.
    @errata = @errata.
              includes(:errata_brew_mappings).
              includes(:product_versions => [:push_targets, :rhel_release])
  end

  def process_push_job_filter
    where = []

    if @have_errata_filter
      where << {:errata_id => @errata}
    end

    if (value = @query_filter['id'])
      where << {:id => value}
    end

    if (value = @query_filter['pub_task_id'])
      where << {:pub_task_id => value}
    end

    if (value = @query_filter['target_name'])
      where << {:type => push_job_types_for_targets(value)}
    end

    if @query_filter['current'].to_bool
      where << (<<-'END_SQL').strip_heredoc
        id = (SELECT MAX(id)
              FROM push_jobs max_push_jobs
              WHERE push_jobs.type=max_push_jobs.type
                  AND push_jobs.errata_id=max_push_jobs.errata_id)
      END_SQL
    end

    @push_jobs = filtered_relation(PushJob, where)

    Rails.logger.debug "Filtered push jobs: #{@push_jobs.to_sql}"
  end

  def filtered_relation(rel, where, joins = [])
    rel = rel.joins(*joins.uniq)
    where.each do |args|
      args = Array.wrap(args)
      rel = rel.where(*args)
    end
    rel
  end

  # Sets @query_filter to the filter requested in parameters.
  #
  # (Mostly for consistency with ApiController base class, which we don't use.)
  def create_filter
    @query_filter = params[:filter] || {}
  end

  # Sets and does some validation on @have_live, @have_stage.
  #
  # Unlike when pushing a single erratum, this needs to be done before the main
  # action because it affects how we filter errata for push (since live/stage
  # can be done at different states).
  def set_targets
    @have_live = false
    @have_stage = false

    if params['defaults'] == 'live'
      @have_live = true
      return
    elsif params['defaults'] == 'stage'
      @have_stage = true
      return
    end

    # This peeks ahead at the parameters before we've parsed them with
    # PushRequest (since that requires knowing the errata to be pushed first,
    # which we can't find out until we know the targets...)
    #
    # Targets can be passed as an array...
    push_targets = Array.wrap(params['_json']).map{ |t| t['target'] }.compact
    if push_targets.blank?
      # Or could be passed in the top-level element
      push_targets = Array.wrap(params['target'])
    end

    all_policies = Push::Policy.policies.values

    push_targets.sort.each do |target_name|
      policy = all_policies.find{ |pol| target_name == pol.push_target.to_s }
      if policy
        @have_live  ||= !policy.staging
        @have_stage ||= policy.staging
      end
    end

    # Empty or bad targets would be validated elsewhere anyway, but just to be
    # clear about this precondition...
    if !@have_live && !@have_stage
      raise DetailedArgumentError.new(:target => 'must specify at least one live or stage target')
    end
  end

  def set_default_states
    # Default states are based on targets, if not specified in filter
    @default_states = []
    if @have_live
      @default_states.concat(State::LIVE_PUSH_STATES)
    end
    if @have_stage
      @default_states.concat(State::STAGE_PUSH_STATES)
    end
    @default_states.uniq!
  end

  # Create and return push jobs for the given +push_spec+
  # (array of [errata, targets, policies] triples).
  #
  # Creates all the requested jobs or raises an error.
  #
  # Intended to be called within a transaction.
  def create_push_jobs_for_requests(push_requests)
    created_jobs = []
    errors = {}

    # Create push jobs. Create as many as possible and collect errors, so we
    # can report all problems at once.
    push_requests.each do |push_request|
      push_request.targets.each do |t|
        begin
          created_jobs << create_push_job(t, push_request)
        rescue => error
          # Catch errors to merge them into a single error object, but if
          # there's an unmergeable kind of error, just re-raise it.
          unless error.respond_to?(:field_errors)
            raise
          end
          error.field_errors.each do |key, value|
            key = key.to_s
            target_name = t.name
            unless key.include?(target_name)
              key = [target_name, key].join(' ')
            end
            errors["#{push_request.errata.advisory_name} #{key}"] = value
          end
        end
      end
    end

    if errors.present?
      raise DetailedArgumentError.new(errors)
    end

    created_jobs
  end

  # Given push target names as used in the API, in +targets+,
  # return corresponding push job classes as used in the database.
  def push_job_types_for_targets(targets)
    types = Set.new
    all_policies = Push::Policy.policies.values

    Array.wrap(targets).each do |target|
      policies = all_policies.select do |pol|
        next true if target == 'live' && !pol.staging
        next true if target == 'stage' && pol.staging
        pol.push_target.to_s == target
      end

      types = types.union policies.map(&:job_klass).map(&:name)
    end

    types.to_a
  end

  def find_push_job
    @push_job = PushJob.find(params['id'])
  end

  # True if pushing in dry run mode
  def dryrun?
    # Trying to be helpful here and tolerate a misspell...
    #
    # It would be quite annoying to attempt requesting a dry run and
    # accidentally push it for real.
    %w[dryrun dry-run].any? do |key|
      params.fetch(key, false).to_bool
    end
  end
end
