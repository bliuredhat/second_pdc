# :api-category: Legacy
class ProductVersionsController < ApplicationController
  include ManageUICommon
  include BrewTaggable

  before_filter :admin_restricted
  before_filter ProductShortNameFilter, :only => [:index, :new, :create]
  before_filter :find_by_id_or_name, :only => [:show, :edit, :update, :set_channels]
  before_filter :set_push_target_params, :only => [:create, :update]
  respond_to :html, :json, :xml

  # GETs should be safe (see http://www.w3.org/2001/tag/doc/whenToUseGet.html)
  verify :method => :post, :only => [ :destroy, :create, :add_tag, :remove_tag, :text_for_solution ],
         :redirect_to => { :action => :index }

  #
  # Fetch a list of product versions belonging to a product.
  #
  # :api-url: /products/{shortname}/product_versions.json
  # :api-method: GET
  #
  # The response contains basic information.
  # [/products/{shortname}/product_versions/{id}.json] may be used to
  # fetch additional information for a single product version.
  #
  # Example response:
  #
  # ```` JavaScript
  # [
  #  {
  #    "product_version": {
  #      "allow_rhn_debuginfo": true,
  #      "default_brew_tag": "dist-5E-qu-candidate",
  #      "is_rhel_addon": false,
  #      "base_product_version_id": null,
  #      "name": "RHEL-5",
  #      "rhel_release_id": 7,
  #      "id": 16,
  #      "is_server_only": 0,
  #      "push_types": [
  #                     'rhn_live',
  #                     'rhn_stage',
  #                     'ftp'],
  #      "product_id": 16,
  #      "description": "Red Hat Enterprise Linux 5",
  #      "is_oval_product": true,
  #      "enabled": 1,
  #      "sig_key_id": 6
  #    }
  #  },
  #  {
  #    "product_version": {
  #      "allow_rhn_debuginfo": true,
  #      "default_brew_tag": "RHEL-5.8-Z-candidate",
  #      "is_rhel_addon": false,
  #      "base_product_version_id": 16,
  #      "name": "RHEL-5.8.Z",
  #      "rhel_release_id": 25,
  #      "id": 204,
  #      "is_server_only": 0,
  #      "supports_cdn": false,
  #      "forbid_ftp": false,
  #      "product_id": 16,
  #      "description": "Red Hat Enterprise Linux 5",
  #      "is_oval_product": true,
  #      "enabled": 1,
  #      "sig_key_id": 6
  #    }
  #  }
  # ]
  # ````
  def index
    @product_versions = ProductVersion.where(:product_id => @product).order('enabled desc, name')
    set_page_title "Product Versions for #{@product.name}"
    respond_with(@product_versions)
  end

  def edit
    extra_javascript %w[product_versions_edit edit_brew_tags]
    @product = @product_version.product
  end

  #
  # Fetch detailed information for a specific product version.
  #
  # :api-url: /products/{shortname}/product_versions/{id}.json
  # :api-method: GET
  #
  # Example response:
  #
  # ```` JavaScript
  # {
  #   "default_brew_tag": "dist-6E-qu-candidate",
  #   "allow_rhn_debuginfo": true,
  #   "name": "RHEL-6",
  #   "sig_key": {
  #     "name": "redhatrelease2",
  #     "id": 8
  #   },
  #   "id": 149,
  #   "is_server_only": false,
  #   "description": "Red Hat Enterprise Linux 6",
  #   "product": {
  #     "name": "Red Hat Enterprise Linux",
  #     "id": 16,
  #     "short_name": "RHEL"
  #   },
  #   "is_oval_product": true,
  #   "rhel_release": {
  #     "name": "RHEL-6",
  #     "id": 15
  #   },
  #   "enabled": true,
  #   "channels": [
  #                {
  #                  "active": true,
  #                  "variant": {
  #                    "name": "6Workstation",
  #                    "id": 348
  #                  },
  #                  "name": "rhel-i386-workstation-fastrack-6",
  #                  "id": 49,
  #                  "type": "FastTrackChannel",
  #                  "arch": "i386",
  #                  "product_version_id": 149
  #                },
  #                {
  #                  "active": true,
  #                  "variant": {
  #                    "name": "6Server",
  #                    "id": 340
  #                  },
  #                  "name": "rhel-ppc64-server-fastrack-6",
  #                  "id": 38,
  #                  "type": "FastTrackChannel",
  #                  "arch": "ppc64",
  #                  "product_version_id": 149
  #                },
  #                /* ... more channels ... */
  #                {
  #                  "active": true,
  #                  "variant": {
  #                    "name": "6Client-optional",
  #                    "id": 341
  #                  },
  #                  "name": "rhel-x86_64-client-optional-6",
  #                  "id": 10,
  #                  "type": "PrimaryChannel",
  #                  "arch": "x86_64",
  #                  "product_version_id": 149
  #                }
  #               ],
  #   "brew_tags": [
  #                 "RHEL-6.4",
  #                 "RHEL-6.4-pending",
  #                 "RHEL-6.4-candidate",
  #                 "dist-6E-qu-candidate"
  #                ]
  # }
  # ````
  def show
    extra_javascript 'edit_brew_tags'
    extra_stylesheet %w[anchorjs-link]
    @variant_map = VariantDisplayMap.for_product_version(@product_version)

    respond_to do |format|
      format.html do
        set_page_title "Product Version '#{@product_version.name}'"
        pv_tags = @product_version.brew_tags.sort
        @releases_with_tags = @product_version.releases.select do |release|
          ((rel_tags = release.brew_tags).any? && rel_tags.sort != pv_tags)
        end
      end
      format.json do
        prod = @product_version.product
        hsh = { :product => {:id => prod.id, :name => prod.name, :short_name => prod.short_name}}
        [:id,
         :name,
         :description,
         :default_brew_tag].each { |m| hsh[m] = @product_version.send(m)}

        [:is_server_only,
         :enabled,
         :is_server_only,
         :allow_rhn_debuginfo,
         :is_oval_product].each { |m| hsh[m] = @product_version.send("#{m}?")}

        hsh[:push_types] = @product_version.push_targets.map(&:push_type)

        [:rhel_release, :sig_key].each do |m|
          o = @product_version.send(m)
          hsh[m] = { :id => o.id, :name => o.name}
        end

        tags = @product_version.brew_tags.collect {|t| t.name}
        tags << @product_version.default_brew_tag unless @product_version.default_brew_tag.blank?
        hsh[:brew_tags] = tags.uniq
        active_channels = @product_version.active_channels.to_set
        all_channels = active_channels.union @product_version.channels
        hsh[:channels] = []
        active_channels.sort_by(&:name).each do |c|
          hsh[:channels] << {
            :id => c.id,
            :name => c.name,
            :type => c.type,
            :variant => {:id => c.variant.id, :name => c.variant.name},
            :arch => c.arch.name,
            :product_version_id => c.product_version.id,
            :active => active_channels.include?(c)
          }
        end
        render :json => hsh.to_json
      end
    end
  end

  def new
    @product_version = ProductVersion.new(:product => @product)
  end

  def create
    @product_version = ProductVersion.new(params[:product_version])
    @product_version.product = @product
    respond_to do |format|
      if @product_version.save
        tag_name = @product_version.default_brew_tag.strip if @product_version.default_brew_tag
        unless tag_name.blank?
          tag = BrewTag.find_or_create_by_name(tag_name)
          @product_version.brew_tags << tag
        end
        format.json {render :json => @product_version.to_json}
        format.html {
          flash_message :notice, "New Product version #{@product_version.name} created."
          redirect_to :action => :show, :id => @product_version.id
        }
      else
        format.json { render :json => {:errors => @product_version.errors}.to_json,
          :status => :unprocessable_entity  }
        format.html { render :action => 'new' }
      end
    end
  end

  def update
    respond_to do |format|
      params[:product_version][:push_targets] ||= [] # handle case where no checkboxes are checked
      if @product_version.update_attributes(params[:product_version])
        format.html do
          flash_message :notice, 'Update succeeded'
          redirect_to :action => 'show', :id => @product_version
        end
        format.json { render :json => @product_version.to_json }
      else
        format.html { render :action => 'edit' }
        format.json { render :json => {:errors => @product_version.errors}.to_json,
          :status => :unprocessable_entity  }
      end
    end
  end

  def destroy
    ProductVersion.find(params[:id]).destroy
    redirect_to :action => 'list'
  end

  # Adds channels to a product version
  #
  # Ignores any channels that are already active for the product version.
  # If the channel is already belongs to the product version, links it
  # If it belongs to a different product version, finds and links it;
  # link validation will restrict to valid base_product_version relationship
  #
  # Example:
  #
  # options = {:body =>
  #   {:channels =>
  #     [{"arch"=>"x86_64",
  #        "name"=>"rhel-x86_64-foobar-6",
  #        "variant"=>{"name"=>"6Server"},
  #        "type"=>"PrimaryChannel"}]}
  # }
  #
  # HTTParty.post('http://localhost:3000/product_versions/set_channels/149.json', options)
  #
  def set_channels
    @active = @product_version.active_channels.each_with_object({}) {|c,h| h[c.name] = c}
    @member = @product_version.channels.each_with_object({}) {|c,h| h[c.name] = c}

    added = []
    channel_data = params[:channels]
    begin
      Channel.transaction do
        channel_data.each do |c|
          name = c['name']
          next if @active.has_key?(name)
          added << add_channel(c)
        end
      end
    rescue => e
      logger.error e.backtrace.join("\n")
      return redirect_to_error!(e.message)
    end
    respond_to do |format|
      format.html do
        flash_message :notice, "Added channels: #{added.collect {|a| a.name}.join(', ')}"
        redirect_back
      end
      format.json { render :json => added.collect {|a| a.name}}
    end
  end

  private

  # set push target as object in parameters for create and update
  # TODO: There is a better way of doing this with nested attributes, need to
  # set up that method
  def set_push_target_params
    return unless params[:product_version] && params[:product_version][:push_targets]
    params[:product_version][:push_targets] = PushTarget.find params[:product_version][:push_targets]
  end

  def add_channel(data)
    name = data['name']
    if Channel.exists?(['name = ?', name])
      channel = @member[name]
      unless channel
        channel = Channel.find_by_name name
      end
      ChannelLink.create!(:channel => channel,
                          :product_version => @product_version,
                          :variant => channel.variant)
      return channel
    else
      return make_channel(data)
    end
  end

  def make_channel(data)
    arch = Arch.find_by_name! data['arch']
    variant = Variant.find_by_name!(data['variant'])
    #variant ||= Variant.find(data['variant']['id'])
    type = data['type']
    klass = Channel.child_get type
    klass.create!(:name => data['name'],
                  :arch => arch,
                  :variant => variant,
                  :product_version => @product_version
                  )
  end
end
