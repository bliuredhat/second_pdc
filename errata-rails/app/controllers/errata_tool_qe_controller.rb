#
# Will add some misc methods for the Errata Tool QE team to
# use when testing stuff. (None of this should be accessible
# in production).
#
# See related methods in a/c/concerns/user_authentication.
#
class ErrataToolQeController < ApplicationController
  include CurrentUser
  skip_before_filter :readonly_restricted
  before_filter :errata_tool_qe_restricted
  before_filter :set_current_user_ivar

  before_filter :get_role, :only => [:add_role, :remove_role]

  def add_role
    @current_user.roles << @role unless @current_user.roles.include?(@role)
    redirect_back
  end

  def remove_role
    @current_user.roles = @current_user.roles.reject{ |r| r == @role }
    redirect_back
  end

  def toggle_visibility_cookie
    cookies[:qe_menu_visible] = errata_tool_qe_visible? ? '0' : '1'
    redirect_back
  end

  private

  def get_role
    role_name = params[:role].to_s
    @role = Role.find_by_name(role_name)
  end

  def errata_tool_qe_restricted
    if errata_tool_qe_available?
      true
    else
      redirect_to_error!("Errata Tool QE functions not available!", 404)
    end
  end

end
