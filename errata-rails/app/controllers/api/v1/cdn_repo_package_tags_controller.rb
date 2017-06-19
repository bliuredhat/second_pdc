# :api-category: CDN Repositories
class Api::V1::CdnRepoPackageTagsController < Api::V1::ApiController

  before_filter :admin_restricted, :only => [:create, :destroy, :update]
  before_filter :map_cdn_repo_package_tag_parameters, :only => [:create, :update]

  private

  # Whitelisted create parameters
  def cdn_repo_package_tag_params
    whitelisted_params :tag_template, :cdn_repo_package_id, :variant_id
  end

  def whitelisted_params(*valid_keys)
    resource_params = params[:cdn_repo_package_tag]
    if !resource_params
      raise DetailedArgumentError.new(
        :codes => :invalid_params,
        :label => 'no cdn_repo_package_tag parameters found'
      )
    end
    invalid_params = resource_params.keys.map(&:to_sym) - valid_keys
    if invalid_params.any?
      logger.info 'Received unexpected params: %p' % [invalid_params]
      raise DetailedArgumentError.new(
        :codes => :invalid_params,
        :params => invalid_params
      )
    end
    resource_params.slice(*valid_keys)
  end

  def resource_query
    resource_class.joins(:cdn_repo_package => [:cdn_repo, :package]).joins('
      LEFT OUTER JOIN errata_versions ON errata_versions.id = cdn_repo_package_tags.variant_id
    ').uniq
  end

  def render_params
    { :order_by => [:cdn_repo_package_id, 'LOWER(tag_template) ASC'] }
  end

  def valid_filter_attributes
    super + [Package.table_name, CdnRepo.table_name, Variant.table_name]
  end

  def apply_filter_transformations
    return if @query_filter.blank?
    cdn_repo_filter = {}
    package_filter = {}
    variant_filter = {}

    if (cdn_repo_id = @query_filter.delete(:cdn_repo_id))
      cdn_repo_filter[:id] = cdn_repo_id
    end
    if (cdn_repo_name = @query_filter.delete(:cdn_repo_name))
      cdn_repo_filter[:name] = cdn_repo_name
    end
    if (package_id = @query_filter.delete(:package_id))
      package_filter[:id] = package_id
    end
    if (package_name = @query_filter.delete(:package_name))
      package_filter[:name] = package_name
    end
    if (variant_id = @query_filter.delete(:variant_id))
      variant_filter[:id] = variant_id
    end
    if (variant_name = @query_filter.delete(:variant_name))
      variant_filter[:name] = variant_name
    end

    @query_filter[CdnRepo.table_name] = cdn_repo_filter if cdn_repo_filter.any?
    @query_filter[Package.table_name] = package_filter if package_filter.any?
    @query_filter[Variant.table_name] = variant_filter if variant_filter.any?
  end

  def map_cdn_repo_package_tag_parameters
    package_tag_params = params[:cdn_repo_package_tag]
    return unless package_tag_params

    # This is only required for create (POST)
    map_cdn_repo_package_id(package_tag_params) if request.post?

    # This is required for create or update (POST/PUT)
    map_variant_name(package_tag_params)
  end

  #
  # Get cdn_repo_package_id from cdn_repo and package id or name
  #
  def map_cdn_repo_package_id(params)
    if !params.has_key?(:cdn_repo_package_id)
      # CdnRepo and Package can be specified by id or name
      cdn_repo_id = extract_id_from_params(CdnRepo, params)
      package_id = extract_id_from_params(Package, params)

      mapping = CdnRepoPackage.where(:cdn_repo_id => cdn_repo_id, :package_id => package_id).first
      raise DetailedArgumentError.new(:package => "is not mapped to CDN repository") if mapping.nil?

      params[:cdn_repo_package_id] = mapping.id
    end
  end

  def map_variant_name(params)
    if (variant_name = params.delete(:variant_name))
      raise DetailedArgumentError.new(:variant_name => 'cannot be specified with variant_id') if params[:variant_id]
      params[:variant_id] = Variant.find_by_name(variant_name).id
    end
  end

  def extract_id_from_params(klass, params)
    attr_prefix = klass.to_s.underscore
    id_attr = "#{attr_prefix}_id".to_sym
    name_attr = "#{attr_prefix}_name".to_sym
    id = params.delete(id_attr)
    if params[name_attr]
      raise DetailedArgumentError.new(name_attr => "cannot be specified with #{id_attr}") if id
      id = klass.find_by_name!(params.delete(name_attr)).id
    end
    raise DetailedArgumentError.new(klass.to_s => "Either #{id_attr} or #{name_attr} must be specified") unless id
    return id
  end

  public

  #
  # Get details of all CDN repository package tags ordered by cdn_repo_id and tag_template.
  #
  # :api-url: /api/v1/cdn_repo_package_tags
  # :api-method: GET
  # :api-response-example: file:test/data/api/v1/cdn_repo_package_tags/index.json
  #
  # Returns an array of cdn_repo_package_tags under the top-level key 'data'.
  # The array may be empty depending on the filters used. The meaning of each
  # attribute is documented under [GET /api/v1/cdn_repo_package_tags/{id}]
  #
  # This is a [paginated API].
  #
  # ##### Filtering
  # The list of cdn_repo_package_tags can be filtered by applying `filter[key]=value` as a
  # query parameter. The attributes `tag_template`, `cdn_repo_id`, `cdn_repo_name`, `package_id`,
  # `package_name`, `variant_id` and `variant_name` can be used.
  #
  def _api_doc_index
  end

  #
  # Get the details of a CDN repository package tag by its id.
  #
  # :api-url: /api/v1/cdn_repo_package_tags/{id}
  # :api-method: GET
  # :api-response-example: file:test/data/api/v1/cdn_repo_package_tags/existing_2.json
  #
  # Parameters are returned under the top-level key `data` which is further
  # divided into `attributes`. Data contains the following keys
  #
  # * `id`: unique identifier of the cdn_repo_package_tag
  # * `type`: "cdn_repo_package_tags" string to indicate the type of resource
  #
  # ##### Attributes
  #
  # * `tag_template`: Tag template string
  #
  # ##### Relationships
  #
  # The following relationships are returned under `data.relationships`. Each
  # relationship has an `id` which is a unique identifier of that resource
  #
  # * `cdn_repo`: CDN repository
  # * `package`: Package that tag will be applied to
  # * `variant`: Variant the tag is restricted to (optional)
  #
  def _api_doc_show
  end

  #
  # Create a new CDN repository package tag.
  #
  # :api-url: /api/v1/cdn_repo_package_tags
  # :api-method: POST
  # :api-response-example: file:test/data/api/v1/cdn_repo_package_tags/create.json
  #
  # The response format on success is the same as for [GET /api/v1/cdn_repo_package_tags/{id}].
  #
  # ##### Attributes
  #
  # The following attributes may be specified. A cdn_repo must be specified
  # using either `cdn_repo_id` or `cdn_repo_name`. A package must be specified
  # using either `package_id` or `package_name`. The package must be mapped to
  # the cdn_repo.
  #
  # A variant may be specified using `variant_id` or `variant_name`. The tag
  # will only be applied when pushing the specified variant. If a variant is
  # not specified, the tag will be applicable to all variants.
  #
  # * `tag_template`: Tag template (string, mandatory)
  # * `cdn_repo_id`: CDN Repository Id (integer)
  # * `cdn_repo_name`: CDN Repository Name (string)
  # * `package_id`: Package Id (integer)
  # * `package_name`: Package name (string)
  # * `variant_id`: Variant Id (integer)
  # * `variant_name`: Variant name (string)
  #
  def _api_doc_create
  end

  #
  # Delete an existing CDN repository package tag.
  #
  # :api-url: /api/v1/cdn_repo_package_tags/{id}
  # :api-method: DELETE
  #
  # On success, the HTTP response will contain no message body, and the HTTP status code
  # will be 204 (No Content).
  #
  def _api_doc_destroy
  end

  #
  # Update attributes for an existing CDN repository package tag.
  #
  # :api-url: /api/v1/cdn_repo_package_tags/{id}
  # :api-method: PUT
  #
  # The response format on success is the same as for [GET /api/v1/cdn_repo_package_tags/{id}].
  #
  # Only the `tag_template` attribute and `variant_id` or `variant_name` may be updated.
  #
  def _api_doc_update
  end

end
