module CurrentUser
  extend ActiveSupport::Concern

  # Allow these methods to be used in views
  included do
    helper_method :current_user
    helper_method :current_user_permitted?
    helper_method :current_user_in_role?
  end

  def current_user
    Thread.current[:current_user]
  end

  def set_current_user_ivar
    @current_user = current_user
  end

  def current_user_permitted?(permission_type, *args)
    current_user && current_user.permitted?(permission_type, *args)
  end

  def current_user_in_role?(*role_names)
    current_user && current_user.in_role?(*role_names)
  end
end
