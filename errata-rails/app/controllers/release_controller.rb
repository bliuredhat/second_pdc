class ReleaseController < ApplicationController
  include BrewTaggable, ReplaceHtml

  POST_METHODS = [ :destroy, :create, :update, :add_tag, :remove_tag ]
  before_filter :validate_roles, :only => POST_METHODS

  before_filter :set_index_nav, :except => POST_METHODS
  
  verify :method => :post, :only => POST_METHODS,
         :redirect_to => { :action => :list }

  respond_to :html, :json
  
  def create
    @type = params[:type]
    @release = Release.child_get(@type).new(params[:release])
    if @release.save
      flash_message :notice, 'Release was successfully created.'
      redirect_to :action => :show, :id => @release
    else
      set_versions
      # in this condition is_pdc should not be checked
      if @release.product && !@release.product.supports_pdc? && @release.is_pdc?
        params.delete(:is_pdc)
        @release.is_pdc = false
      end
      render :action => :new_by_type
    end
  end

  def destroy
    Release.find(params[:id]).destroy
    redirect_to :action => 'list'
  end

  def edit
    @release = Release.find(params[:id])
    @pdc_releases = []
    @pdc_releases_id_in_use = []
    if @release.is_pdc?
      get_pdc_releases_info
    end
    @current_versions = @release.product_versions.to_set
    @is_editing = true
    @type = @release.class.to_s
    set_versions
    set_page_title "Release #{@release.name}"
  end

  def index
    redirect_to :action => :active_releases
  end

  def list
    redirect_to :action => :active_releases
  end

  def active_releases
    set_page_title "Active Release Groups"
    set_release_types(true)
  end
  
  def inactive_releases
    set_page_title "Inactive Release Groups"
    set_release_types
  end
  
  def new

  end

  def new_by_type
    @type = params[:type]
    @release = Release.child_get(@type).new
    @release.product = Product.find_by_short_name('RHEL')
    @ship_date = ''
    set_versions
    set_page_title "New #{@type} Release"
  end

  # Ajax response to update product versions when changing the product
  def product_versions_for_product

    if params[:id]
      @current_versions = Release.find(params[:id]).product_versions.to_set
    end

    versions = []
    if params[:release].blank? || params[:release][:product_id].blank?
      Product.where('isactive = ?', true).each {|prod| versions.concat(prod.product_versions)}
    else
      product = Product.find(params[:release][:product_id])
      versions = product.product_versions
    end
    replace_with_partial :product_version_list, 'product_version_list', :object => versions
  end

  # Ajax response to update  PDC releases when changing the product
  def pdc_releases_for_product
    if params[:id]
      @release = Release.find(params[:id])
    end
    product = Product.find(params[:release][:product_id]) unless params[:release][:product_id].empty?
    @in_error = false
    begin
      pdc_releases = get_releases_from_pdc_by_product(product).map do |rel_from_pdc|
        PdcRelease.find_or_create_by_pdc_id(rel_from_pdc.release_id)
      end
    rescue Curl::Err::CurlError, Faraday::ConnectionFailed
      @in_error = true
    end
    replace_with_partial :pdc_release_list, 'pdc_release_list', :object => pdc_releases
  end

  # Ajax response to update the page when changing the type
  def fields_for_release_type
    @release = Release.find(params[:id])
    @type = params[:release][:type]
    replace_with_partial :fields_for_release_type,  "new_#{@type.downcase}"
  end

  def show
    @release = Release.find(params[:id])
    set_page_title "Release #{@release.name}"
    respond_with(@release)
  end

  def update
    @release = Release.find(params[:id])
    if @release.is_pdc?
      params[:release][:pdc_releases] ||= []
      if (pdc_ids = params[:release][:pdc_releases]).any?
        params[:release][:pdc_releases] = PdcRelease.where(pdc_id: pdc_ids)
      end
      # data of pdc releases in use will not be submitted because it's disabled in edit page.
      # even disabled attribute is removed by some ways, these pdc releases should not be excluded.
      if (pdc_release_ids_in_use = @release.pdc_release_ids_in_use).any?
        params[:release][:pdc_releases] += PdcRelease.where(id: pdc_release_ids_in_use)
      end
    end

    if params[:release][:type] != @release.class.name
      # Must update type explicitly since Rails won't do it in update_attributes
      # Do it first so we get the right validations
      @release.type = params[:release][:type]
    end

    params[:release][:product_version_ids] ||= [] # handle case where no checkboxes are checked

    if @release.update_attributes(params[:release])
      flash_message :notice, 'Release was successfully updated.'
      redirect_to :action => 'show', :id => @release
    else
      @type = @release.class.to_s
      set_versions
      if @release.is_pdc?
        get_pdc_releases_info
        @is_editing = true
      end
      render :action => 'edit'
    end
  end

  private

  def validate_roles
    validate_user_roles('admin', 'pm')
  end

  def set_release_types(enabled = false)
    conditions = 'enabled = 1' if enabled
    conditions ||= 'enabled = 0'
    
    @release_types = { }
    [Async,FastTrack,Zstream,QuarterlyUpdate].each do |type|
      @release_types[type] = type.find(:all, :conditions => conditions, :order => 'name')
    end    
  end
  
  def get_secondary_nav
    return [
            { :name => 'Active Releases', :controller => :release, :action => :active_releases},
            { :name => 'Inactive Releases', :controller => :release, :action => :inactive_releases}
           ]
  end

  
  def set_versions
    @versions = []
    if @release.product
      @versions = @release.product.product_versions
    else
      Product.where('isactive = ?', true).each {|prod| @versions.concat(prod.product_versions)}
    end
  end

  def get_releases_from_pdc
    get_releases_from_pdc_by_product(@release.product)
  end

  def get_releases_from_pdc_by_product(product)
    return [] unless product && product.pdc_product
    product.pdc_product.pdc_releases
  end

  def get_pdc_releases_info
    @pdc_releases = []
    @pdc_releases_id_in_use = []
    begin
      @pdc_releases = get_releases_from_pdc.map do |rel_from_pdc|
        PdcRelease.get(rel_from_pdc.release_id)
      end
      @pdc_releases_id_in_use = @release.pdc_release_ids_in_use
        # todo: use PDC::Error => e to replace following exception after
        #       pdc ruby gem implemented related part
    rescue Curl::Err::HostResolutionError, Faraday::ConnectionFailed
      redirect_to_error!("Can't access PDC server, please try again later.")
    rescue Curl::Err::CurlError => e
      redirect_to_error!(e.message)
    end
  end

end

