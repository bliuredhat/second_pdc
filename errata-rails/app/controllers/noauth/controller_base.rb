class Noauth::ControllerBase < ActionController::Base

  before_filter do
    # Want to make sure the current user is cleared in case passenger reuses a thread.
    # See bug 921000.
    Thread.current[:current_user] = nil
  end

end
