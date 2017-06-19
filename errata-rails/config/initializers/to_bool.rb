# Patch to_bool instance methods on some types we commonly need to coerce to
# bool. Mainly for handling form inputs and database fields which commonly
# represent booleans as 0/1 or "0"/"1".
#
# Derived from this MIT-licensed code:
# https://github.com/bricker/to_bool/blob/02c2792df553158a1e8f0a1010a7b0c8dd34d122/lib/to_bool.rb

class String
  def to_bool
    as_int = to_i
    if as_int.to_s == self
      # Integers formatted as strings can be coerced to bool via int
      as_int.to_bool
    else
      # Any other strings cannot be coerced (even the obvious ones like "true"
      # or "false", until there's a use-case for it)
      fail ArgumentError, "String #{inspect.truncate(60)} is not a boolean"
    end
  end
end

class Integer
  # C-like semantics
  def to_bool
    self != 0
  end
end

class TrueClass
  def to_bool
    self
  end
end

class FalseClass
  def to_bool
    self
  end
end

class NilClass
  def to_bool
    false
  end
end
