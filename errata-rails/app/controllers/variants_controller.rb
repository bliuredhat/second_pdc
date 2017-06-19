# :api-category: Legacy
class VariantsController < ApplicationController
  include ManageUICommon
  include ErrorHandling

  before_filter :admin_restricted
  before_filter :find_product_version, :only => [:index, :new, :create]
  before_filter :find_by_id_or_name, :except => [:index, :new, :create]
  before_filter :process_params, :only => [:create, :update]
  around_filter :with_validation_error_rendering
  respond_to :html, :json

  #
  # Fetch a list of variants belonging to a product version.
  #
  # :api-url: /product_versions/{product_version_id}/variants.json
  # :api-method: GET
  #
  # The response contains basic information.
  # [/variants/{id}.json] may be used to
  # fetch additional information for a single variant.
  #
  # Example response:
  #
  # ```` JavaScript
  # [
  #  {
  #    "id":91,
  #    "name":"4AS",
  #    "description":"Red Hat Enterprise Linux AS version 4",
  #    "cpe":"cpe:/o:redhat:enterprise_linux:4::as",
  #    "tps_stream":"RHEL-4-Main-AS",
  #    "enabled":true,
  #    "product":{
  #      "id":16,
  #      "short_name":"RHEL"
  #    },
  #    "product_version":{
  #      "id":3,
  #      "name":"RHEL-4"
  #    },
  #    "rhel_variant":{
  #      "id":91,
  #      "name":"4AS"
  #    },
  #    "rhel_release":{
  #      "id":3,
  #      "name":"RHEL-4"
  #    }
  #  },
  #  {
  #    "id":92,
  #    "name":"4ES",
  #    "description":"Red Hat Enterprise Linux ES version 4",
  #    "cpe":"cpe:/o:redhat:enterprise_linux:4::es",
  #    "tps_stream":"RHEL-4-Main-ES",
  #    "enabled":true,
  #    "product":{
  #      "id":16,
  #      "short_name":"RHEL"
  #    },
  #    "product_version":{
  #      "id":3,
  #      "name":"RHEL-4"
  #    },
  #    "rhel_variant":{
  #      "id":92,
  #      "name":"4ES"
  #    },
  #    "rhel_release":{
  #      "id":3,
  #      "name":"RHEL-4"
  #    }
  #  }
  # ]
  # ````
  #
  # GETs should be safe (see http://www.w3.org/2001/tag/doc/whenToUseGet.html)
  def index
    @variants =  Variant.where(:product_version_id => @product_version)
    respond_with(@variants)
  end

  #
  # Get the details of single variant by its id.
  #
  # :api-url: /variants/{id}.json
  # :api-method: GET
  #
  # Example response:
  #
  # ```` JavaScript
  # {
  #   "id":699,
  #   "name":"7Client",
  #   "description":"Red Hat Enterprise Linux Client (v. 7)",
  #   "cpe":"cpe:/o:redhat:enterprise_linux:7::client",
  #   "tps_stream":"RHEL-7-Main-Client",
  #   "enabled":true,
  #   "product":{
  #     "id":16,
  #     "short_name":"RHEL"
  #   },
  #   "product_version":{
  #     "id":244,
  #     "name":"RHEL-7"
  #   },
  #   "rhel_variant":{
  #     "id":699,
  #     "name":"7Client"
  #   },
  #   "rhel_release":{
  #     "id":27,
  #     "name":"RHEL-7"
  #   }
  # }
  # ````
  def show
    extra_stylesheet %w[anchorjs-link]
    @product_version = @variant.product_version
    respond_with(@variant)
  end

  def new
    @variant = Variant.new
    @variant.product_version = @product_version
  end

  def create
    create_or_update_variant
  end

  def edit
  end

  def disable
    @variant.update_attribute(:enabled, false)
    flash_message :notice, "Disabled variant #{@variant.name}"
    redirect_to request.referer
  end

  def enable
    @variant.update_attribute(:enabled, true)
    flash_message :notice, "Enabled variant #{@variant.name}"
    redirect_to request.referer
  end

  def update
    create_or_update_variant
  end

  protected

  def create_or_update_variant(opts = {})
    if params[:variant].try(:has_key?, :cpe) && !can_edit_cpe?
      redirect_to_error! 'You do not have permission to edit CPE', :forbidden
      return
    end

    if action_name == 'create'
      opts[:options] = { :product_version => @product_version }
    end

    create_or_update(opts) do |dist_repo|
      message = "Variant '#{@variant.name}' was successfully #{action_name}d."
      to_url = product_version_variant_url(@variant.product_version, @variant)
      redirect_to(to_url, :notice => message)
    end
  end

  def process_params
    v_attrs = params[:variant]
    if v_attrs && v_attrs.has_key?(:push_targets)
      v_attrs[:push_targets] ||= []
      v_attrs[:push_targets].reject!(&:blank?)
      v_attrs[:push_targets] = PushTarget.find_by_id_or_name(v_attrs[:push_targets])
      # just to make sure it is saved
      params[:variant] = v_attrs
    end
  end

  def find_product_version
    @product_version = ProductVersion.find_by_id_or_name(params[:product_version_id])
  end
end
