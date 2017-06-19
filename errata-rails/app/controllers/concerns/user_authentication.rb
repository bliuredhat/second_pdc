module UserAuthentication
  extend ActiveSupport::Concern
  include CurrentUser

  included do
    helper_method :remote_user

    helper_method :errata_tool_qe_available?
    helper_method :errata_tool_qe_visible?
  end

  protected
  def admin_restricted
    if request.get?
      return true
    else
      validate_user_roles('admin', 'releng')
    end
  end

  def clear_thread
    Thread.current[:current_user] = nil
  end

  def check_auth(user)
    return unknown_user_error! unless user
    return unknown_user_error! unless user.enabled?
    return unknown_user_error! unless user.in_role?('errata')
    return check_post_auth(user)
  end

  def check_post_auth(user)
    return true if request.get?
    return true if params[:controller] == 'errata' && params[:action] == 'find'
    return true if params[:controller] == 'errata' && params[:action] == 'index'
    return true if params[:controller] == 'errata' && params[:action] == 'delete_filter'
    return true if params[:controller] == 'user' && params[:action] == 'update_preferences'
    return true if params[:controller] == 'errata_tool_qe'
    if user.is_readonly?
      return permission_error!('readonly')
    end
    return true
  end

  def check_user_auth
    Thread.current[:current_user] = nil

    if Rails.env.development?
      user = User.fake_devel_user
      return false unless check_auth(user)
      Thread.current[:current_user] = user
      return true
    end

    unless remote_user
      respond_to do |format|
        format.html { render :file => 'shared/site_messages/no_kerberos', :status => 401 }
        format.json { render :json => {:error => 'Kerberos credentials required'}, :status => 401 }
        format.any  { render :text => "Kerberos credentials required", :status => 401 }
      end
      return false
    end

    user = User.find_by_login_name(remote_user)
    return false unless check_auth(user)
    Thread.current[:current_user] = user

    return true
  end

  def raw_remote_user
    # If running in mod_passenger, server will use REMOTE_USER
    return request.env['REMOTE_USER'] if request.env['SERVER_SOFTWARE'] =~ /Apache/
    return request.env['HTTP_X_REMOTE_USER']
  end

  def remote_user
    out = raw_remote_user
    return nil if out.nil?
    out += "@#{Settings.remote_user_realm}" unless out =~ /@/
    out
  end
  # Added this in Bz 703408 so we can use it in guess_remote_user helper..

  def permission_error!(*roles)
    logger.error "Invalid resource access attempt by #{current_user.to_s} for #{controller_name}/#{action_name}\n" +
      "Resource needed one of #{roles.join(', ')} roles."
    redirect_to_error!("You do not have permission to access this resource.", :unauthorized)
  end

  def readonly_restricted
    return true unless current_user.is_readonly?
    return permission_error!('readonly')
  end

  def pusherrata_restricted
    validate_user_roles('pusherrata')
  end

  def security_restricted
    validate_user_roles('secalert')
  end

  def super_user_restricted
    validate_user_roles('super-user')
  end

  def batch_admin_restricted
    validate_user_permission(:manage_batches)
  end

  def unknown_user_error!
    respond_to do |format|
      format.html { render :file => 'shared/site_messages/no_user_access', :status => 403 }
      format.any  { render :text => "User does not have access", :status => 403 }
    end
    return false
  end

  def validate_user_roles(*roles)
    unless current_user.in_role?(*roles)
      return permission_error!(*roles)
    end
    return true
  end

  def validate_user_permission(permission_type)
    validate_user_roles(*UserPermissions::ROLE_PERMISSIONS[permission_type])
  end

  #
  # Not really user auth related, but let's put
  # these here. See errata_tool_qe_controller.
  #
  def errata_tool_qe_visible?
    errata_tool_qe_available? && cookies[:qe_menu_visible].to_bool
  end

  def errata_tool_qe_available?
    current_user && (Rails.env.development? || (Rails.env.staging? && ErrataSystem::SYSTEM_HOSTNAME == 'errata.app.qa.eng.nay.redhat.com'))
  end

end
