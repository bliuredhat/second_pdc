# :api-category: Users
class Api::V1::UserController < ApplicationController
  include SharedApi::Users

  respond_to :json

  before_filter :admin_restricted

  around_filter :with_transaction, :except => [:show]
  around_filter :with_validation_error_rendering
  before_filter :find_by_id_param, :only => [:show, :update]
  before_filter :sanitize_user_params, :only => [:create, :update]

  verify :method => :post, :only => [:create]
  verify :method => :put, :only => [:update]

  #
  # Get the details of a user account.
  #
  # :api-url: /api/v1/user/{id_or_login_name}
  # :api-method: GET
  # :api-response-example: file:test/data/api/v1/user/create.json
  #
  # The meaning of each field is documented under [/api/v1/user].
  #
  def show
  end

  #
  # Create a new user account.
  #
  # :api-url: /api/v1/user
  # :api-method: POST
  # :api-request-example: file:test/data/api/v1/user/create.json
  #
  # Mandatory parameters:
  #
  # * `login_name`: Red Hat email for real person or kerberos id for special/machine user (string)
  # * `realname`: User's real name (string)
  #
  # Optional parameters:
  #
  # * `organization`: User's OrgChart group (string). For real person accounts Errata Tool will update this from the Organizational Chart, so setting it has limited usefulness.
  # * `roles`: User's roles in Errata Tool. (array)
  # * `enabled`: User's status. Default is true. (boolean)
  # * `receives_mail`: User will receive email notification. Default is true. Special/machine user is required to set email_address to receive email notification.
  # * `email_address`: If specified, user will receive any notification via this email address instead of login_name from Kerberos principal.
  #
  def create
    create_new_user
    render 'show', :status => :created
  end

  #
  # Update an existing user account.
  #
  # :api-url: /api/v1/user/{id_or_login_name}
  # :api-method: PUT
  #
  # The request body uses the same parameters as [/api/v1/user], but
  # all parameters are optional.
  #
  def update
    set_user_details
    render 'show'
  end

  private

  def find_by_id_param
    id_or_name = params[:id]
    if (@user = find_user_by_id_or_name(id_or_name)).nil?
      field = (id_or_name =~ /^\d+$/) ? :id : :login_name
      raise DetailedArgumentError.new(field => "#{id_or_name} not found.")
    end
  end

  def sanitize_user_params
    @user_params = params
    if @user_params[:organization].present?
      name = @user_params[:organization]
      if (@user_params[:organization] = UserOrganization.find_by_name(name)).nil?
        raise DetailedArgumentError.new(:organization => "#{name} not found.")
      end
    end

    # protect users against passing in "true" or "false" strings without realizing
    check_enabled = @user_params.has_key?(:enabled)
    enabled = @user_params[:enabled]
    if check_enabled && enabled != true && enabled != false
      raise DetailedArgumentError.new(:enabled => "expected boolean, got #{enabled.class}")
    end

    roles = @user_params[:roles] || [] if @user_params.has_key?(:roles)
    if roles && roles.kind_of?(Array)
      roles.reject!(&:blank?)
      @user_params[:roles] = Role.where(:name => roles).order("name ASC").to_a

      not_found = roles - @user_params[:roles].map(&:name).uniq
      if not_found.any?
        raise DetailedArgumentError.new(:roles => "#{not_found.join(', ')} #{not_found.size >1 ? 'are' : 'is'} invalid.")
      end
    elsif !roles
      # get user's current roles if no role is specified when updating user details
      # otherwise set it to empty array
      @user_params[:roles] ||= @user ? @user.roles : []
    else
      raise DetailedArgumentError.new(:roles => "must be an array.")
    end
  end
end
