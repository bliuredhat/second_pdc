# Represents that something is not available, with a reason.
class NotAvailable
  attr_accessor :reason

  def initialize(reason)
    @reason = reason
  end

  def available?
    false
  end
end
