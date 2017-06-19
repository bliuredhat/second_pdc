# This class can be used to wrap an ActiveModel::Errors to allow certain errors
# to be accessed under aliased keys.
#
# The purpose of this class is to support cases where the reading and writing
# methods for an attribute have different names.  In that case, due to the
# expectations of certain code, such as the field_with_errors wrapping in rails,
# it's useful for the error to be accessible from within the errors object using
# either method name.  However, we don't want to store the error in the error
# object twice under two different keys, since many places in the UI/API would
# then display it twice.
#
# So this wraps an Errors object such that certain errors can be accessed by
# multiple keys, but are only returned once by methods such as full_messages,
# keys, etc.
class ErrorsWithAlias < SimpleDelegator
  def initialize(delegate, aliases)
    @aliases = aliases
    super(delegate)
  end

  def [](key)
    key = key.to_sym
    key = @aliases.fetch(key, key)
    super(key)
  end
end
