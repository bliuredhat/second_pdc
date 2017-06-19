#
# These two methods are defined in Rails 4, but not in Rails 3.
#
#   http://apidock.com/rails/v4.0.2/ActionView/Helpers/CacheHelper/cache_if
#   http://apidock.com/rails/v4.0.2/ActionView/Helpers/CacheHelper/cache_unless
#
module CacheIfHelper

  def cache_if(condition, name = {}, options = nil, &block)
    if condition
      cache(name, options, &block)
    else
      yield
    end

    nil
  end

  def cache_unless(condition, name = {}, options = nil, &block)
    cache_if !condition, name, options, &block
  end

end
