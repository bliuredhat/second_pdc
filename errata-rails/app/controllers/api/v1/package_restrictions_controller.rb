#
# The JSON api allows user with administrator role to limit the targets
# where a package for a particular variant should be pushed, such as RHN Live
# and RHN Stage.
#
# :api-category: Pushing Advisories
class Api::V1::PackageRestrictionsController < ApplicationController
  include SharedApi::PackageRestrictions
  respond_to :json

  before_filter :admin_restricted
  before_filter :find_variant_and_package, :only => [:set, :delete]
  before_filter :find_push_targets, :only => [:set]
  verify :method => :post, :only => [:set, :delete]

  #
  # Restrict the push targets of a package for a particular variant.
  #
  # Updates the restriction if it exists, otherwise creates a new restriction.
  #
  # :api-url: /api/v1/package_restrictions/set
  # :api-method: POST
  # :api-request-example: {"variant": "6Server", "package": "qemu-kvm", "push_targets": ["rhn_live", "rhn_stage"]}
  #
  # * `variant`: Variant name or id (string)
  # * `package`: Package name or id (string)
  # * `push_targets`: List of push targets' name or id to be set (string)
  #
  def set
    begin
      @package_restriction = find_package_restriction
    rescue ActiveRecord::RecordNotFound => error
      # create a new restriction if not exist
      create_restriction
    else
      # otherwise update the restriction
      update_restriction
    end
  end

  #
  # Delete a restriction of a package for a particular variant.
  #
  # :api-url: /api/v1/package_restrictions/delete
  # :api-method: POST
  # :api-request-example: {"variant": "6Server", "package": "qemu-kvm"}
  #
  # * `variant`: Variant name or id (string)
  # * `package`: Package name or id (string)
  #
  def delete
    begin
      @package_restriction = find_package_restriction
    rescue ActiveRecord::RecordNotFound => error
      # use own error message
      error = error.exception(
        "Couldn't find package restriction with variant"\
        " #{@attr_params[:variant].name} and #{@attr_params[:package].name}.")
      error_notice(error)
    else
      delete_restriction
    end
  end

  private

  def success_notice(message)
    render :json => {:notice => message}, :status => :ok
  end

  def error_notice(error)
    respond_to do |format|
      render_json_error(format, error)
    end
  end

  def find_package_restriction
    return PackageRestriction.\
      find_by_variant_id_and_package_id!(@attr_params[:variant], @attr_params[:package])
  end

  def find_variant_and_package
    begin
      @attr_params = {
        :variant => Variant.find_by_id_or_name(params[:variant]),
        :package => Package.find_by_id_or_name(params[:package]),
      }
    rescue ActiveRecord::RecordNotFound => error
      error_notice(error)
    end
  end

  def find_push_targets
    begin
      push_targets = nil
      # When user passes an empty array from json api ( e.g. {"push_targets":[]} ),
      # the params[:push_targets] will be nil. Therefore, the codes set the value to
      # [] if it is nil
      push_targets = params[:push_targets] || [] if params.has_key?(:push_targets)
      unless push_targets && push_targets.kind_of?(Array)
        raise ArgumentError, "Invalid or missing push targets."
      end
      push_targets.reject!(&:blank?)
      @attr_params[:push_targets] = PushTarget.find_by_id_or_name(push_targets)
    rescue ArgumentError, ActiveRecord::RecordNotFound => error
      error_notice(error)
    end
  end
end