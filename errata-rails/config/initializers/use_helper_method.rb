#
# If you want to use helper methods inside your controller's actions
# (even though it is arguably a code smell, ie you should push your
# presentation logic down into views rather than have it in your
# controllers), you can include the helper modules you want, for
# example:
#
#     class ThingController < ActionController::Base
#       include ApplicationHelper
#       include ThingHelper
#       ...
#     end
#
# But this will pollute your controller with all the methods from the
# helpers which might be undesirable.
#
# There are various workarounds for this, such as:
# * http://www.johnyerhot.com/2008/01/10/rails-using-helpers-in-you-controller/
# * http://snippets.dzone.com/posts/show/1799
# * http://masonoise.wordpress.com/2010/01/16/using-rails-tag-helpers-in-a-controller/
#
# You can also access any helper from a controller action using something like
# this:
#
#     ActionController::Base.helpers.some_helper
#     ThingController.helpers.some_helper
#
# or even this (?)
#
#     self.class.helpers.other_helper
#
# but that fairly inconvenient and awkward looking, so let's make it nicer.
#
# This defines the use_helper_method which can be used as follows:
#
#     class ThingController < ActionController::Base
#       use_helper_method :some_helper, :other_helper
#       ...
#       def some_action
#         ...
#         @message = "Hello #{some_helper(@thing)}\n\nRegards #{other_helper(@user)}"
#       end
#     end
#
# It will create a private method in your controller that just calls
# the helpers you specified. Now you can call some_helper and pluralize
# directly from your action methods.
#
# (Not to be confused with ActionController::Base.helper_method and
# ActionController::Base.helper which do very different things...)
#
# Note: This is kind of experimental. There might be a better way to
# do it.
#
class ActionController::Base
  def self.use_helper_method(*syms)
    syms.each do |helper_method|
      class_eval <<-EOM
        private
        def #{helper_method}(*args)
          self.class.helpers.#{helper_method}(*args)
        end
      EOM
    end
  end
end
