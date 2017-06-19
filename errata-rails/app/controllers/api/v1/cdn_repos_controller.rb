# :api-category: CDN Repositories
class Api::V1::CdnReposController < Api::V1::ApiController

  before_filter :admin_restricted, :only => [:create, :update]
  before_filter :map_cdn_repo_parameters, :only => [:create, :update]
  before_filter :no_locked_packages, :only => :update

  private

  # Whitelisted create parameters
  def cdn_repo_params
    whitelisted_params(:name, :content_type, :release_type, :variant_id, :variant_name, :arch_id, :arch_name, :use_for_tps, :package_ids, :package_names)
  end

  # Whitelisted update parameters
  def update_params
    whitelisted_params(:name, :variant_id, :variant_name, :arch_id, :arch_name, :use_for_tps, :package_ids, :package_names)
  end

  def whitelisted_params(*valid_keys)
    cdn_repo_params = params[:cdn_repo]
    if !cdn_repo_params
      raise DetailedArgumentError.new(
        :codes => :invalid_params,
        :label => 'no cdn_repo parameters found'
      )
    end
    invalid_params = cdn_repo_params.keys.map(&:to_sym) - valid_keys
    if invalid_params.present?
      logger.info 'Received unexpected params: %p' % [invalid_params]
      raise DetailedArgumentError.new(
        :codes => :invalid_params,
        :params => invalid_params
      )
    end
    cdn_repo_params.slice(*valid_keys)
  end

  def no_locked_packages
    return unless update_params[:package_ids].present?
    locked_package_names = CdnRepoPackage.
                           where(
                             'cdn_repo_id = ? and package_id not in (?)',
                             @cdn_repo.id,
                             update_params[:package_ids]
                           ).
                           reject(&:can_destroy?).
                           map(&:package).
                           map(&:name)
    if locked_package_names.any?
      logger.info "Package(s) #{locked_package_names.join(', ')} is(are) in use"
      raise DetailedArgumentError.new(
              :code => :package_in_use,
              :locked_packages => locked_package_names
            )
    end
  end

  def resource_query
    resource_class.joins(:arch).joins('
      LEFT OUTER JOIN cdn_repo_links ON cdn_repo_links.cdn_repo_id = cdn_repos.id
      LEFT OUTER JOIN errata_versions ON errata_versions.id = cdn_repo_links.variant_id
    ').uniq
  end

  def render_params
    { :order_by => 'LOWER(cdn_repos.name) ASC' }
  end

  def valid_filter_attributes
    super + [Arch.table_name, Variant.table_name]
  end

  def apply_filter_transformations
    return if @query_filter.blank?
    map_parameter_values(@query_filter)

    {
      :content_type => :type,
      :use_for_tps  => :has_stable_systems_subscribed,
    }.each{|k, v|
      @query_filter[v] = @query_filter.delete k if @query_filter.has_key?(k)
    }

    if (arch_name = @query_filter.delete(:arch_name))
      @query_filter[Arch.table_name] = {:name => arch_name}
    end
    if (variant_name = @query_filter.delete(:variant_name))
      @query_filter[Variant.table_name] = {:name => variant_name}
    end
  end

  def map_cdn_repo_parameters
    cdn_repo_params = params[:cdn_repo]
    return unless cdn_repo_params

    map_parameter_values(cdn_repo_params)
    map_linked_variants(cdn_repo_params)
  end

  #
  # Map certain attribute values to internal format.
  # No need to do reverse, as this is handled by view.
  #
  def map_parameter_values(params)
    if (content_type = params[:content_type])
      params[:content_type] = "Cdn#{content_type}Repo" unless content_type.starts_with?('Cdn')
    end
    if (release_type = params[:release_type])
      release_type = 'Eus' if release_type == 'EUS'
      params[:release_type] = "#{release_type}CdnRepo" unless release_type.ends_with?('CdnRepo')
    end
    if (package_names = params.delete(:package_names))
      raise DetailedArgumentError.new(:package_names => 'cannot be specified with package_ids') if params[:package_ids]
      params[:package_ids] = package_names.map{|n| Package.make_from_name(n).id}
    end
  end

  #
  # Multiple variants can be linked to cdn_repos through cdn_repo_links.
  # These can be specified using variant_ids or variant_names. As these
  # are not really attributes, they need to be handled a bit differently.
  #
  # The first specified variant is considered to be the variant_id that
  # "owns" the repo (the variant_id attribute of the cdn_repo). The
  # @variants are processed after @cdn_repo has been updated.
  #
  def map_linked_variants(params)
    get_variants = lambda do |attr, list|
      variants = Variant.where(attr => list).all
      if variants.count != list.count
        missing = list - variants.map(&attr)
        raise DetailedArgumentError.new(:variants => "cannot find #{'variant'.pluralize(missing.count)}: #{missing.join(', ')}")
      end
      variants
    end

    # Can only have one variant parameter in the request
    incompatible_params(params, :variant_id, :variant_ids, :variant_name, :variant_names)

    if (variant_names = Array.wrap(params.delete(:variant_names))).any?
      @variants = get_variants.call(:name, variant_names)
      params[:variant_id] = Variant.find_by_name(variant_names.first).id
    elsif (variant_ids = Array.wrap(params.delete(:variant_ids))).any?
      @variants = get_variants.call(:id, variant_ids)
      params[:variant_id] = variant_ids.first
    end
  end

  def incompatible_params(params, *keys)
    found = params.slice(*keys).keys.sort
    return if found.length <= 1
    raise DetailedArgumentError.new(found.shift => "cannot be specified with #{found.join(', ')}")
  end

  #
  # This method is called after the @cdn_repo has been updated. If any
  # linked variants were specified in the request, these are created
  # here (and any existing links not specified are removed).
  #
  def after_update
    return true unless @variants

    old_linked_variants = @cdn_repo.links.map(&:variant).uniq
    variants_to_attach = @variants - old_linked_variants
    variants_to_detach = old_linked_variants - @variants

    @cdn_repo.cdn_repo_links.where(:variant_id => variants_to_detach).delete_all if variants_to_detach.any?

    variants_to_attach.each do |variant|
      CdnRepoLink.create!(:cdn_repo_id => @cdn_repo.id, :variant_id => variant.id)
    end

    @cdn_repo.reload
  end

  def after_create
    after_update
  end

  public

  #
  # Get details of all CDN repositories ordered by name.
  #
  # :api-url: /api/v1/cdn_repos
  # :api-method: GET
  # :api-response-example: file:test/data/api/v1/cdn_repos/release_type_EUS.json
  #
  # Returns an array of cdn_repos under the top-level key 'data'.
  # The array may be empty depending on the filters used. The meaning of each
  # attribute is documented under [GET /api/v1/cdn_repos/{id}]
  #
  # This is a [paginated API].
  #
  # ##### Filtering
  # The list of cdn_repos can be filtered by applying `filter[key]=value` as a
  # query parameter. All attributes of a CdnRepo can be used as a filter, including
  # `id`, `arch_id`, `arch_name`, `variant_id` and `variant_name`. When filtering
  # by variant, a record will be returned if the variant is linked to the repository.
  #
  def _api_doc_index
  end

  #
  # Get the details of a CDN repository by its id.
  #
  # :api-url: /api/v1/cdn_repos/{id}
  # :api-method: GET
  # :api-response-example: file:test/data/api/v1/cdn_repos/existing_1275.json
  #
  # Parameters are returned under the top-level key `data` which is further
  # divided into `attributes`. Data contains the following keys
  #
  # * `id`: unique identifier of the cdn_repo
  # * `type`: "cdn_repos" string to indicate the type of resource
  #
  # ##### Attributes
  #
  # * `name`: Pulp repo label (string)
  # * `content_type`: Content Type. One of `Binary`, `Debuginfo`, `Source` (string)
  # * `release_type`: Release type. One of `Primary`, `EUS`, `FastTrack`, `LongLife` (string)
  # * `use_for_tps`: Use for TPS scheduling (boolean)
  #
  # ##### Relationships
  #
  # The following relationships are returned under `data.relationships`. Each
  # relationship has an `id` which is a unique identifier of that resource
  #
  # * `variants`: Array of Variants linked to this repository
  # * `arch`: Arch
  # * `packages`: Array of Packages associated with this repository (currently
  #               only used by Docker CDN repositories)
  #
  def _api_doc_show
  end

  #
  # Create a new CDN repository.
  #
  # :api-url: /api/v1/cdn_repos
  # :api-method: POST
  # :api-request-example: file:publican_docs/Developer_Guide/api_examples/cdn_repos/create.json
  #
  # The response format on success is the same as for [GET /api/v1/cdn_repos/{id}].
  #
  # ##### Attributes
  #
  # The following attributes may be specified. An arch must be specified
  # using either `arch_id` or `arch_name`.
  #
  # One or more variants must be linked to the repository by specifying
  # a variant parameter (`variant_id`, `variant_ids`, `variant_name` or
  # `variant_names`). Only one variant parameter may be specified, but one
  # must be provided.
  #
  # For CDN Docker repositories, a list of associated packages may be specified
  # using either `package_ids` or `package_names`.
  #
  # * `name`: Pulp repo label. Must not include '.' or '/' characters (string, mandatory)
  # * `content_type`: Content Type. One of `Binary`, `Debuginfo`, `Source` (string, mandatory)
  # * `release_type`: Release type. One of `Primary`, `EUS`, `FastTrack`, `LongLife` (string, default `Primary`)
  # * `use_for_tps`: Use for TPS scheduling (boolean, default false)
  # * `arch_id`: ID of arch (integer)
  # * `arch_name`: Name of arch (string)
  # * `package_ids`: array of package ids (array of integer)
  # * `package_names`: array of package names (array of string)
  # * `variant_id`: ID of variant (integer)
  # * `variant_ids`: IDs of variants (array of integer)
  # * `variant_name`: Name of variant (string)
  # * `variant_names`: Names of variants (array of string)
  #
  def _api_doc_create
  end

  #
  # Update attributes for an existing CDN repository.
  #
  # :api-url: /api/v1/cdn_repos/{id}
  # :api-method: PUT
  #
  # The response format on success is the same as for [GET /api/v1/cdn_repos/{id}].
  #
  # Any of the attributes listed for [POST /api/v1/cdn_repos/{id}] may be
  # specified in the request, except for `content_type` and `release_type`.
  #
  # Note: If `package_ids` or `package_names` are specified, the list of packages
  # associated with the repository will be replaced by those in the request.
  #
  # If any variant parameters are specified, only the specified variants will be
  # linked to the repository. Any variants that are currently linked but not
  # specified in the request will be detached from the repository.
  #
  def _api_doc_update
  end

end
