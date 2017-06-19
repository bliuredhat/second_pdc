class MultiProductMappingsController < ApplicationController
  include ManageUICommon, MultiProductMappingSubscription, ReplaceHtml

  around_filter :with_validation_error_rendering

  before_filter :admin_restricted, :except => [:show, :index]
  before_filter :set_variables,
                :only => [
                  :create,
                  :update,
                  :show,
                  :edit,
                  :destroy,
                  :add_subscription,
                  :remove_subscription]
  before_filter :find_mapping,
                :only => [
                  :update,
                  :edit,
                  :show,
                  :destroy,
                  :add_subscription,
                  :remove_subscription]

  verify :method => :post,
         :only => [:create, :add_subscription],
         :redirect_to => { :action => :index }
  verify :method => :put,
         :only => :update,
         :redirect_to => { :action => :index }
  verify :method => :delete,
         :only => [:destroy, :remove_subscription],
         :redirect_to => { :action => :index }

  respond_to :html, :json

  #
  # Fetch a list of all multi product mappings
  #
  # :api-url: /multi_product_mappings.json
  # :api-method: GET
  #
  # The response includes both RHN Channel and CDN Repository mappings.
  #
  # Example response:
  #
  # ```` JavaScript
  # [
  #  {
  #    "destination_cdn_repo": "rhel-7-server-rhev-mgmt-agent-rpms__7Server__x86_64",
  #    "destination_cdn_repo_id": 1358,
  #    "destination_product_version": "RHEL-7-RHEV",
  #    "destination_product_version_id": 272,
  #    "id": 11,
  #    "origin_cdn_repo": "rhel-7-server-optional-rpms__7Server__x86_64",
  #    "origin_cdn_repo_id": 1290,
  #    "origin_product_version": "RHEL-7",
  #    "origin_product_version_id": 244,
  #    "package": "libvirt",
  #    "package_id": 939,
  #    "type": "cdn"
  #  },
  #  {
  #    "destination_cdn_repo": "rhs-3-for-rhel-6-server-rpms__6Server__x86_64",
  #    "destination_cdn_repo_id": 2156,
  #    "destination_product_version": "RHEL-6-RHS-3",
  #    "destination_product_version_id": 334,
  #    "id": 10,
  #    "origin_cdn_repo": "rhel-6-server-optional-rpms__6Server__x86_64",
  #    "origin_cdn_repo_id": 245,
  #    "origin_product_version": "RHEL-6",
  #    "origin_product_version_id": 149,
  #    "package": "sanlock",
  #    "package_id": 16700,
  #    "type": "cdn"
  #  }
  # ]
  # ````
  def index
    if params[:scope] == "all"
      @channel_mappings = MultiProductChannelMap.includes([:origin_product_version, :destination_product_version, :origin_channel, :destination_channel, :package, :user])
      @cdn_repo_mappings = MultiProductCdnRepoMap.includes([:origin_product_version, :destination_product_version, :origin_cdn_repo, :destination_cdn_repo, :package, :user])
    else
      @channel_mappings = MultiProductChannelMap.with_enabled_product_version.includes([:origin_channel, :destination_channel, :package, :user])
      @cdn_repo_mappings = MultiProductCdnRepoMap.with_enabled_product_version.includes([:origin_cdn_repo, :destination_cdn_repo, :package, :user])
    end

    set_page_title "Multiple Product Channel/Repo Mappings"

    @all_mappings = @channel_mappings.to_a + @cdn_repo_mappings.to_a
    respond_with(@all_mappings)
  end

  def new
    set_page_title 'New Multi Product Mapping'
    extra_javascript 'multi_product_mappings'
    @multi_product_mapping = MultiProductChannelMap.new
  end

  def create
    @multi_product_mapping = @map_class.new(mapping_params)
    if @multi_product_mapping.save
      flash_message :notice, "Multi product mapping has been created."
      redirect_to :action => :show,
                  :id => @multi_product_mapping,
                  :mapping_type => @map_class.mapping_type
    else
      extra_javascript 'multi_product_mappings'
      render :new
    end
  end

  #
  # Fetch the details of single multi product mapping.
  # Mapping type is required as a parameter to query from proper mapping.
  # It should be either of 'channel' and 'cdn_repo'
  #
  # :api-url: /multi_product_mappings/{id}.json?mapping_type={mapping_type}
  # :api-method: GET
  #
  # Example response:
  #
  # ```` javaScript
  # {
  #   "multi_product_cdn_repo_map": {
  #     "created_at": "2015-11-17T00:49:01Z",
  #     "destination_cdn_repo_id": 2156,
  #     "destination_product_version_id": 334,
  #     "id": 10,
  #     "origin_cdn_repo_id": 245,
  #     "origin_product_version_id": 149,
  #     "package_id": 16700,
  #     "updated_at": "2015-11-17T00:49:01Z",
  #     "user_id": 3000656
  #   }
  # }
  # `````
  def show
    set_page_title "Multi Product Mapping for #{@multi_product_mapping.package}"
    respond_to do |format|
      format.html
      format.json {render :json => @multi_product_mapping.to_json}
    end
  end

  def edit
    set_page_title "Edit Multi Product Mapping for #{@multi_product_mapping.package}"
  end

  def update
    @multi_product_mapping.assign_attributes(mapping_params)
    if @multi_product_mapping.save
      flash_message :notice, 'Multi product mapping has been updated.'
      redirect_to :action => :show,
                  :id => @multi_product_mapping,
                  :mapping_type => @multi_product_mapping.mapping_type
    else
      render :edit
    end
  end

  def destroy
    @multi_product_mapping.destroy
    redirect_to :action => :index
  end

  private

  def set_variables
    type = form_params[:mapping_type] unless form_params.nil?
    type ||= params[:mapping_type]

    @mapping_type = type.to_sym unless type.blank?
    case @mapping_type
    when MultiProductChannelMap.mapping_type
      @map_class = MultiProductChannelMap
      @dist_class = Channel
    when MultiProductCdnRepoMap.mapping_type
      @map_class = MultiProductCdnRepoMap
      @dist_class = CdnRepo
    else
      raise DetailedArgumentError,
            'Mapping Type' => "Invalid mapping type: '#{@mapping_type}'"
    end
  end

  def find_mapping
    @multi_product_mapping = @map_class.find(params[:id])
  end

  def find_dist_by_name(name)
    @dist_class.find_by_name(name)
  end

  def mapping_params
    package = Package.find_by_name!(form_params[:package])
    src_dist = find_dist_by_name(form_params[:origin])
    dest_dist = find_dist_by_name(form_params[:destination])
    {
      :package => package,
      "origin_#{@mapping_type}" => src_dist,
      "destination_#{@mapping_type}" => dest_dist,
      :origin_product_version => src_dist.try(:product_version),
      :destination_product_version => dest_dist.try(:product_version),
      :user => current_user
    }
  end

  def form_params
    params["multi_product_cdn_repo_map"] || params["multi_product_channel_map"]
  end
end
