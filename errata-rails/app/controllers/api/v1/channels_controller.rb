# :api-category: RHN Channels
class Api::V1::ChannelsController < Api::V1::ApiController

  before_filter :admin_restricted, :only => [:create, :update]
  before_filter :map_channel_parameters, :only => [:create, :update]

  private

  # Whitelisted create parameters
  def channel_params
    whitelisted_params(:name, :release_type, :variant_id, :variant_name, :arch_id, :arch_name, :use_for_tps)
  end

  # Whitelisted update parameters
  def update_params
    whitelisted_params(:name, :variant_id, :variant_name, :arch_id, :arch_name, :use_for_tps)
  end

  def whitelisted_params(*valid_keys)
    channel_params = params[:channel]
    if !channel_params
      raise DetailedArgumentError.new(
        :codes => :invalid_params,
        :label => 'no channel parameters found'
      )
    end
    invalid_params = channel_params.keys.map(&:to_sym) - valid_keys
    if invalid_params.present?
      logger.info 'Received unexpected params: %p' % [invalid_params]
      raise DetailedArgumentError.new(
        :codes => :invalid_params,
        :params => invalid_params
      )
    end
    channel_params.slice(*valid_keys)
  end

  def resource_query
    resource_class.joins(:arch).joins('
      LEFT OUTER JOIN channel_links ON channel_links.channel_id = channels.id
      LEFT OUTER JOIN errata_versions ON errata_versions.id = channel_links.variant_id
    ').uniq
  end

  def render_params
    { :order_by => 'LOWER(channels.name) ASC' }
  end

  def valid_filter_attributes
    super + [Arch.table_name, Variant.table_name]
  end

  def apply_filter_transformations
    return if @query_filter.blank?
    map_parameter_values(@query_filter)

    {
      :release_type => :type,
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

  def map_channel_parameters
    channel_params = params[:channel]
    return unless channel_params

    map_parameter_values(channel_params)
    map_linked_variants(channel_params)
  end

  #
  # Map certain attribute values to internal format.
  # No need to do reverse, as this is handled by view.
  #
  def map_parameter_values(params)
    if (release_type = params[:release_type])
      release_type = 'Eus' if release_type == 'EUS'
      params[:release_type] = "#{release_type}Channel" unless release_type.ends_with?('Channel')
    end
  end

  #
  # Multiple variants can be linked to channels through channel_links.
  # These can be specified using variant_ids or variant_names. As these
  # are not really attributes, they need to be handled a bit differently.
  #
  # The first specified variant is considered to be the variant_id that
  # "owns" the channel (the variant_id attribute of the channel). The
  # @variants are processed after @channel has been updated.
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
  # This method is called after the @channel has been updated. If any
  # linked variants were specified in the request, these are created
  # here (and any existing links not specified are removed).
  #
  def after_update
    return true unless @variants

    old_linked_variants = @channel.links.map(&:variant).uniq
    variants_to_attach = @variants - old_linked_variants
    variants_to_detach = old_linked_variants - @variants

    @channel.channel_links.where(:variant_id => variants_to_detach).delete_all if variants_to_detach.any?

    variants_to_attach.each do |variant|
      ChannelLink.create!(:channel_id => @channel.id, :variant_id => variant.id)
    end

    @channel.reload
  end

  def after_create
    after_update
  end

  public

  #
  # Get details of all RHN Channels ordered by name.
  #
  # :api-url: /api/v1/channels
  # :api-method: GET
  # :api-response-example: file:test/data/api/v1/channels/release_type_LongLife.json
  #
  # Returns an array of channels under the top-level key 'data'.
  # The array may be empty depending on the filters used. The meaning of each
  # attribute is documented under [GET /api/v1/channels/{id}]
  #
  # This is a [paginated API].
  #
  # ##### Filtering
  # The list of channels can be filtered by applying `filter[key]=value` as a
  # query parameter. All attributes of a Channel can be used as a filter, including
  # `id`, `arch_id`, `arch_name`, `variant_id` and `variant_name`. When filtering
  # by variant, a record will be returned if the variant is linked to the channel.
  #
  def _api_doc_index
  end

  #
  # Get the details of an RHN Channel by its id.
  #
  # :api-url: /api/v1/channels/{id}
  # :api-method: GET
  # :api-response-example: file:test/data/api/v1/channels/existing_1024.json
  #
  # Parameters are returned under the top-level key `data` which is further
  # divided into `attributes`. Data contains the following keys
  #
  # * `id`: unique identifier of the channel
  # * `type`: "channels" string to indicate the type of resource
  #
  # ##### Attributes
  #
  # * `name`: Channel name (string)
  # * `release_type`: Release type. One of `Primary`, `EUS`, `FastTrack`, `LongLife` (string)
  # * `use_for_tps`: Use for TPS scheduling (boolean)
  #
  # ##### Relationships
  #
  # The following relationships are returned under `data.relationships`. Each
  # relationship has an `id` which is a unique identifier of that resource
  #
  # * `variants`: Array of Variants linked to this channel
  # * `arch`: Arch
  #
  def _api_doc_show
  end

  #
  # Create a new RHN Channel.
  #
  # :api-url: /api/v1/channels
  # :api-method: POST
  # :api-request-example: file:publican_docs/Developer_Guide/api_examples/channels/create.json
  #
  # The response format on success is the same as for [GET /api/v1/channels/{id}].
  #
  # ##### Attributes
  #
  # The following attributes may be specified. An arch must be specified
  # using either `arch_id` or `arch_name`.
  #
  # One or more variants must be linked to the channel by specifying
  # a variant parameter (`variant_id`, `variant_ids`, `variant_name` or
  # `variant_names`). Only one variant parameter may be specified, but one
  # must be provided.
  #
  # * `name`: Channel name (string, mandatory)
  # * `release_type`: Release type. One of `Primary`, `EUS`, `FastTrack`, `LongLife` (string, default `Primary`)
  # * `use_for_tps`: Use for TPS scheduling (boolean, default false)
  # * `arch_id`: ID of arch (integer)
  # * `arch_name`: Name of arch (string)
  # * `variant_id`: ID of variant (integer)
  # * `variant_ids`: IDs of variants (array of integers)
  # * `variant_name`: Name of variant (string)
  # * `variant_names`: Names of variants (array of strings)
  #
  def _api_doc_create
  end

  #
  # Update attributes for an existing RHN Channel.
  #
  # :api-url: /api/v1/channels/{id}
  # :api-method: PUT
  #
  # The response format on success is the same as for [GET /api/v1/channels/{id}].
  #
  # Any of the attributes listed for [POST /api/v1/channels/{id}] may be
  # specified in the request, except for `release_type`.
  #
  # If any variant parameters are specified, only the specified variants will be
  # linked to the channel. Any variants that are currently linked but not
  # specified in the request will be detached from the channel.
  #
  def _api_doc_update
  end

end
