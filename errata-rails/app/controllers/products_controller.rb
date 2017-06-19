# :api-category: Legacy
class ProductsController < ApplicationController
  include ManageUICommon, ReplaceHtml

  before_filter :admin_restricted, :except => [:rpm_prefixes]
  before_filter ProductShortNameFilter, :only => [:show, :edit, :update]
  before_filter :set_push_target_params, :only => [:create, :update]
  respond_to :html, :json, :xml
  # GETs should be safe (see http://www.w3.org/2001/tag/doc/whenToUseGet.html)
  verify :method => :post, :only => [ :destroy, :create],
  :redirect_to => { :action => :list }

  #
  # Fetch a list of all products.
  #
  # :api-url: /products.json
  # :api-method: GET
  #
  # The response includes both active and inactive products.
  #
  # Example response:
  #
  # ```` JavaScript
  # [
  #  {
  #    "product": {
  #      "allow_ftp": 1,
  #      "default_solution_id": 2,
  #      "short_name": "RHEL",
  #      "valid_bug_states": [
  #                           "MODIFIED",
  #                           "VERIFIED"
  #                          ],
  #      "build_path": null,
  #      "ftp_path": "os",
  #      "name": "Red Hat Enterprise Linux",
  #      "path": "/mnt/redhat/beehive/updates/dist",
  #      "id": 16,
  #      "description": "Errata Related to Red Hat Advanced Products",
  #      "ftp_subdir": "os",
  #      "isactive": 1
  #    }
  #  },
  #  {
  #    "product": {
  #      "allow_ftp": 1,
  #      "default_solution_id": 1,
  #      "short_name": "RHCS",
  #      "valid_bug_states": [
  #                           "MODIFIED",
  #                           "VERIFIED"
  #                          ],
  #      "build_path": null,
  #      "ftp_path": "os",
  #      "name": "Red Hat Cluster Suite",
  #      "path": "/mnt/redhat/beehive/updates/dist",
  #      "id": 20,
  #      "description": "Red Hat Cluster Suite",
  #      "ftp_subdir": "RHCS",
  #      "isactive": 1
  #    }
  #  }
  # ]
  # ````
  def index
    set_page_title 'Products'
    @products = Product.all # includes inactive products (but they start hidden)
    respond_with(@products)
  end

  def disabled
    set_page_title 'Disabled Products'
    @products = Product.where(:isactive => false)
    render :action => 'index'

  end

  #
  # Fetch one product.
  #
  # :api-url: /products/{shortname}.json
  # :api-method: GET
  #
  # Returns a single element using the same format as
  # [/products.json].
  def show
    respond_with(@product)
  end

  def new
    set_page_title 'New Product'
    @product = Product.new
    @product.default_solution = DefaultSolution.default_default_solution
  end

  def create
    @product = Product.new(params[:product])
    if @product.save
      redirect_to product_url(@product), :notice => "Product #{@product.name} was created."
    else
      render :action => :new
    end
  end

  def edit
    @product = Product.find(params[:id])
    @solutions = DefaultSolution.find :all
    @pdc_products = []
    @is_editing = true
    get_pdc_product_list if @product.supports_pdc?
  end

  def update
    params[:product][:push_targets] ||= [] # handle case where no checkboxes are checked
    if @product.update_attributes(params[:product])
      redirect_to product_url(@product), :notice => "Product #{@product.name} was successfully updated."
    else
      @is_editing = true
      get_pdc_product_list if @product.supports_pdc?

      render :action => :edit
    end
  end

  def text_for_solution
    id = params[:product][:default_solution_id]
    solution = DefaultSolution.find id
    replace_html :default_solution_text, "<pre>#{solution.text.html_safe}</pre>"
  end

  def rpm_prefixes
    @products = BrewRpmNamePrefix.products_with_prefixes
  end

  protected
  # set push target as object in parameters for create and update
  # TODO: There is a better way of doing this with nested attributes, need to
  # set up that method
  def set_push_target_params
    return unless params[:product] && params[:product][:push_targets]
    params[:product][:push_targets] = PushTarget.find params[:product][:push_targets]
  end

  def get_pdc_product_list
    begin
      @pdc_products = PdcProduct.all_products
    # TODO change following exception to PDC exception after
    #      updated to new PDC ruby gem
    rescue Curl::Err::HostResolutionError, Faraday::ConnectionFailed
      redirect_to_error!("Can't access PDC server, please try again later.")
    rescue Curl::Err::CurlError => e
      redirect_to_error!(e.message)
    end
  end
end
