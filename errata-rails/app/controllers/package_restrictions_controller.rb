class PackageRestrictionsController < ApplicationController
  include SharedApi::PackageRestrictions
  before_filter :admin_restricted
  before_filter :find_variant, :only => [:new, :create, :edit]
  before_filter :find_by_id_or_name, :only => [:edit, :update, :destroy]
  before_filter :find_params, :only => [:create, :update]
  before_filter :find_active_errata, :only => [:edit]
  respond_to :html

  def new
    extra_javascript 'view_section'
    @package_restriction = PackageRestriction.new
    @package_restriction.variant = @variant
  end

  def create
    @attr_params.merge!({:variant => @variant})
    create_restriction
  end

  def edit
    extra_javascript 'view_section'
  end

  def update
    update_restriction
  end

  def destroy
    delete_restriction
  end

  private

  def error_notice(error)
    method = :"error_notice_#{params[:action]}"
    return self.send(method, error) if self.respond_to?(method, true)

    # no action-specific error notice, use generic implementation
    flash_message :error, error.message
    redirect_to :back
  end

  def error_notice_create(error)
    flash_message :error, error.message
    # show active errata list and persist value in the fields
    # if package and variant are valid.
    if @package_restriction &&
       @package_restriction.variant &&
       @package_restriction.package
       @active_errata = @package_restriction.active_errata
    else
      self.new
    end
    render :action => 'new'
  end

  def success_notice(message)
    @package_restriction.tap do |pr|
      variant = pr.variant
      product_version = variant.product_version
      redirect_to(product_version_variant_url(product_version, variant), :notice => message)
    end
  end

  def find_params
    @attr_params = {}
    restriction = params[:package_restriction] || {}
    begin
      if restriction.has_key?(:package)
        package = restriction[:package]
        # will get ActiveRecord::AssociationTypeMismatch exception
        # if it is empty string so set to nil
        @attr_params[:package] = package.present? ? Package.find_by_id_or_name(package) : nil
      end

      if restriction.has_key?(:push_targets)
        push_targets = restriction[:push_targets] || []
        push_targets.reject!(&:blank?)
        @attr_params[:push_targets] = PushTarget.find_by_id_or_name(push_targets)
      end
    rescue ActiveRecord::RecordNotFound => error
      error_notice(error)
    end
  end

  def find_variant
    begin
      @variant = Variant.find_by_id_or_name(params[:variant_id])
    rescue ActiveRecord::RecordNotFound => error
      error_notice(error)
    end
  end

  def find_active_errata
    @active_errata = @package_restriction.active_errata
  end
end
